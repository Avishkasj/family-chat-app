import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../data/local_database.dart';
import '../data/models.dart';
import '../data/secure_vault.dart';
import '../shared/content_crypto.dart';
import '../shared/crypto.dart';
import '../shared/device_keys.dart';
import '../shared/handshake.dart';
import '../shared/protocol.dart';
import '../shared/secure_channel.dart';
import 'discovery_service.dart';
import 'notification_service.dart';

enum LinkStatus { notConfigured, connecting, connected, searching, offline, authFailed }

@immutable
class LinkState {
  const LinkState(this.status, {this.reason});
  final LinkStatus status;

  /// For [LinkStatus.authFailed]: one of [AuthFailure].
  final String? reason;

  bool get isConnected => status == LinkStatus.connected;
}

/// Keys of settings stored in the local database.
abstract final class Keys {
  static const familyId = 'family_id';
  static const familyName = 'family_name';
  static const hubHost = 'hub_host';
  static const hubPort = 'hub_port';
  static const isHubOwner = 'is_hub_owner';
  static const lastSeq = 'last_seq';
  static const profileDirty = 'profile_dirty';
  static const keepAlive = 'keep_alive';
  static const notifications = 'notifications';
  static const hubPaused = 'hub_paused';
  static const appLock = 'app_lock';
  static const appLockTimeout = 'app_lock_timeout';
  static String profileVersion(String id) => 'profile_ver:$id';
}

class _Signal {
  Completer<void> _completer = Completer();

  Future<void> wait() => _completer.future;

  void fire() {
    if (!_completer.isCompleted) _completer.complete();
    _completer = Completer();
  }
}

class _Upload {
  _Upload(this.fileId);
  final String fileId;
  int acked = 0;
  Object? error;
  final Completer<void> done = Completer();
  final _Signal changed = _Signal();

  void fail(Object e) {
    error = e;
    if (!done.isCompleted) done.completeError(e);
    changed.fire();
  }
}

class _Download {
  _Download(this.messageId, this.attachment, this.temp, this.sink, this.key);
  final String messageId;
  final Attachment attachment;
  final File temp;
  final IOSink sink;
  final SecretKey key;
  int expected = -1;
  int received = 0;
  final Completer<void> done = Completer();

  void fail(Object e) {
    if (!done.isCompleted) done.completeError(e);
  }
}

class TransferException implements Exception {
  const TransferException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// The device's connection to the family hub and everything that flows over
/// it: sync, the outbox of unsent messages, presence, typing, and encrypted
/// file transfers. All history is persisted in [LocalDatabase].
class ChatService {
  ChatService({
    required this.db,
    required this.vault,
    required this.keys,
    required this.discovery,
    required this.notifications,
    required this.filesDirectory,
  });

  final LocalDatabase db;
  final SecureVault vault;
  final DeviceKeys keys;
  final DiscoveryService discovery;
  final NotificationService notifications;
  final String filesDirectory;

  final ValueNotifier<LinkState> link = ValueNotifier(
    const LinkState(LinkStatus.notConfigured),
  );
  final ValueNotifier<Set<String>> online = ValueNotifier(const {});
  final ValueNotifier<Map<String, Set<String>>> typing = ValueNotifier(
    const {},
  );
  final ValueNotifier<Map<String, double>> progress = ValueNotifier(const {});

  /// Conversation currently on screen (no unread count / notification).
  String? activeConversationId;
  bool appInForeground = true;

  String get myId => keys.deviceId;
  bool get isConfigured => db.getValue(Keys.familyId) != null;
  bool get isHubOwner => db.getBool(Keys.isHubOwner);

  HubConnection? _connection;
  ContentCrypto? _crypto;
  bool _running = false;
  final _Signal _wake = _Signal();
  Future<void> _frameQueue = Future.value();

  bool _syncing = false;
  int _liveMaxSeq = 0;
  int _syncNewMessages = 0;
  bool _hubHasMyProfile = true;

  bool _flushing = false;
  bool _flushAgain = false;
  final Map<String, Completer<void>> _ackWaiters = {};
  final Map<String, _Upload> _uploads = {};
  final Map<String, _Download> _downloads = {};
  final Map<String, Map<String, Timer>> _typingTimers = {};
  final Map<String, DateTime> _lastTypingSent = {};

  // -- lifecycle -------------------------------------------------------------

  /// Saves the hub this device belongs to and starts connecting.
  Future<void> configure({
    required String host,
    required int port,
    required String familyId,
    required String familyName,
    required String inviteCode,
    required bool isHubOwner,
  }) async {
    await vault.setInviteCode(inviteCode);
    db
      ..setValue(Keys.hubHost, host)
      ..setValue(Keys.hubPort, '$port')
      ..setValue(Keys.familyId, familyId)
      ..setValue(Keys.familyName, familyName)
      ..setBool(Keys.isHubOwner, isHubOwner)
      ..setBool(Keys.profileDirty, true)
      ..ensureFamilyConversation(familyName);
    start();
  }

  Future<void> updateInviteCode(String code) async {
    await vault.setInviteCode(code);
    if (link.value.status == LinkStatus.authFailed || !_running) {
      start();
    } else {
      await _connection?.channel.close();
    }
  }

  void start() {
    if (!isConfigured) {
      link.value = const LinkState(LinkStatus.notConfigured);
      return;
    }
    if (_running) {
      reconnectNow();
      return;
    }
    _running = true;
    unawaited(_loop());
  }

  Future<void> stop() async {
    _running = false;
    _wake.fire();
    await _connection?.channel.close();
  }

  /// Retries immediately (app resumed, network changed, user tapped retry).
  void reconnectNow() => _wake.fire();

  Future<void> _loop() async {
    var failures = 0;
    while (_running) {
      final host = db.getValue(Keys.hubHost);
      final port = db.getInt(Keys.hubPort, kHubPort);
      final familyId = db.getValue(Keys.familyId);
      final code = await vault.inviteCode();
      if (host == null || familyId == null || code == null) {
        link.value = const LinkState(LinkStatus.notConfigured);
        _running = false;
        return;
      }
      link.value = const LinkState(LinkStatus.connecting);
      try {
        final connection = await connectToHub(
          host: host,
          port: port,
          inviteCode: code,
          keys: keys,
          expectedFamilyId: familyId,
        );
        failures = 0;
        await _serve(connection);
      } on HubAuthException catch (e) {
        link.value = LinkState(LinkStatus.authFailed, reason: e.reason);
        _running = false;
        return;
      } on HubMismatchException {
        failures = max(failures, 2);
      } catch (e) {
        debugPrint('Hub connection failed: $e');
      }
      if (!_running) break;
      failures++;
      link.value = const LinkState(LinkStatus.offline);

      // The hub's address may have changed (DHCP); look for it again.
      if (failures >= 2 && !isHubOwner) {
        link.value = const LinkState(LinkStatus.searching);
        final hub = await discovery.find(familyId);
        if (hub != null && (hub.host != host || hub.port != port)) {
          db
            ..setValue(Keys.hubHost, hub.host)
            ..setValue(Keys.hubPort, '${hub.port}');
          continue;
        }
        link.value = const LinkState(LinkStatus.offline);
      }
      final delay = Duration(seconds: min(30, 1 << min(failures, 5)));
      await Future.any([Future<void>.delayed(delay), _wake.wait()]);
    }
    if (link.value.status != LinkStatus.authFailed) {
      link.value = LinkState(
        isConfigured ? LinkStatus.offline : LinkStatus.notConfigured,
      );
    }
  }

  Future<void> _serve(HubConnection connection) async {
    _connection = connection;
    _syncing = true;
    _liveMaxSeq = 0;
    final finished = Completer<void>();
    final subscription = connection.channel.frames().listen(
      (frame) {
        _frameQueue = _frameQueue
            .then((_) => _handleFrame(frame))
            .catchError((Object e, StackTrace s) {
              debugPrint('Error handling frame: $e\n$s');
            });
      },
      onError: (Object e) {
        if (!finished.isCompleted) finished.complete();
      },
      onDone: () {
        if (!finished.isCompleted) finished.complete();
      },
      cancelOnError: true,
    );
    try {
      await finished.future;
    } finally {
      await subscription.cancel();
      _connection = null;
      _onDisconnected();
    }
  }

  void _onDisconnected() {
    const error = TransferException('Connection to the family hub was lost');
    for (final waiter in _ackWaiters.values) {
      if (!waiter.isCompleted) waiter.completeError(error);
    }
    _ackWaiters.clear();
    for (final upload in _uploads.values) {
      upload.fail(error);
    }
    for (final download in _downloads.values) {
      download.fail(error);
    }
    for (final timers in _typingTimers.values) {
      for (final timer in timers.values) {
        timer.cancel();
      }
    }
    _typingTimers.clear();
    typing.value = const {};
    final now = DateTime.now();
    for (final id in online.value) {
      if (id != myId) db.upsertMember(id, lastSeen: now, notify: false);
    }
    online.value = const {};
  }

  SecureChannel get _channel {
    final connection = _connection;
    if (connection == null || connection.channel.isClosed) {
      throw const TransferException('Not connected to the family hub');
    }
    return connection.channel;
  }

  // -- incoming frames -------------------------------------------------------

  Future<void> _handleFrame(ChannelFrame frame) async {
    if (frame is ChunkFrame) return _handleChunk(frame);
    final data = (frame as JsonFrame).data;
    switch (frame.type) {
      case Msg.welcome:
        await _handleWelcome(data);
      case Msg.member:
        await _applyMember(data['member'] as Map<String, dynamic>);
      case Msg.presence:
        _applyPresence((data['online'] as List).cast<String>());
      case Msg.conversation:
        await _applyConversation(data['conv'] as Map<String, dynamic>);
      case Msg.message:
        await _applyMessage(data['msg'] as Map<String, dynamic>, live: true);
      case Msg.batch:
        await _handleBatch(data);
      case Msg.ack:
        _handleAck(data);
      case Msg.typing:
        _handleTyping(data['conv'] as String, data['from'] as String);
      case Msg.fileAck:
        final upload = _uploads[data['fileId']];
        if (upload != null) {
          upload.acked = max(upload.acked, data['n'] as int);
          upload.changed.fire();
        }
      case Msg.fileOk:
        final upload = _uploads[data['fileId']];
        if (upload != null && !upload.done.isCompleted) upload.done.complete();
        upload?.changed.fire();
      case Msg.fileInfo:
        final download = _downloads[data['fileId']];
        if (download != null) {
          download.expected = data['chunks'] as int;
          if (download.expected != chunkCountFor(download.attachment.size)) {
            download.fail(const TransferException('File was tampered with'));
          }
        }
      case Msg.fileError:
        _downloads[data['fileId']]?.fail(
          const TransferException('The file is no longer on the hub'),
        );
      case Msg.error:
        _handleError(data);
    }
  }

  Future<void> _handleWelcome(Map<String, dynamic> data) async {
    _crypto = ContentCrypto(
      familyKey: SecretKey(unb64(data['contentKey'] as String)),
      keys: keys,
    );
    final familyName = data['familyName'] as String;
    db
      ..setValue(Keys.familyName, familyName)
      ..ensureFamilyConversation(familyName);

    _hubHasMyProfile = true;
    for (final member in (data['members'] as List).cast<Map<String, dynamic>>()) {
      await _applyMember(member);
    }
    final conversations = (data['conversations'] as List)
        .cast<Map<String, dynamic>>();
    final ids = <String>{};
    for (final conv in conversations) {
      ids.add(conv['id'] as String);
      await _applyConversation(conv);
    }
    // Groups we were removed from while offline.
    for (final conv in db.conversations()) {
      if (conv.type == ConversationType.group &&
          conv.members.contains(myId) &&
          !ids.contains(conv.id)) {
        db.upsertConversation(
          id: conv.id,
          type: ConversationType.group,
          members: conv.members.where((m) => m != myId).toList(),
        );
      }
    }
    _applyPresence((data['online'] as List).cast<String>());
    link.value = const LinkState(LinkStatus.connected);
    unawaited(_afterWelcome());
  }

  Future<void> _afterWelcome() async {
    try {
      if (db.getBool(Keys.profileDirty) || !_hubHasMyProfile) {
        await _publishProfile();
      }
      _syncNewMessages = 0;
      await _channel.sendJson({
        't': Msg.sync,
        'since': db.getInt(Keys.lastSeq),
      });
      await _flushOutbox();
      await _resumeDownloads();
    } catch (e) {
      debugPrint('Post-connect tasks interrupted: $e');
    }
  }

  Future<void> _applyMember(Map<String, dynamic> json) async {
    final id = json['id'] as String;
    final removed = json['removed'] as bool? ?? false;
    final dhKey = unb64(json['dhKey'] as String);
    final existing = db.member(id);
    if (existing?.agreementKey != null &&
        !listEquals(existing!.agreementKey, dhKey)) {
      _crypto?.clearCache();
    }
    final profile = json['profile'] as String?;
    final version = json['profileVer'] as int? ?? 0;
    String? name;
    Uint8List? avatar;
    var clearAvatar = false;
    if (id == myId) {
      _hubHasMyProfile = profile != null;
    } else if (profile != null &&
        version != db.getInt(Keys.profileVersion(id), -1)) {
      try {
        final decoded = await _crypto!.decryptProfile(profile, id);
        name = (decoded['name'] as String? ?? '').trim();
        final avatarB64 = decoded['avatar'] as String?;
        avatar = avatarB64 == null ? null : unb64(avatarB64);
        clearAvatar = avatar == null;
        db.setValue(Keys.profileVersion(id), '$version');
      } catch (e) {
        debugPrint('Could not read profile of $id: $e');
      }
    }
    final lastSeen = json['lastSeen'] as int?;
    db.upsertMember(
      id,
      name: name,
      avatar: avatar,
      clearAvatar: clearAvatar,
      agreementKey: dhKey,
      joinedAt: json['joinedAt'] is int
          ? DateTime.fromMillisecondsSinceEpoch(json['joinedAt'] as int)
          : null,
      lastSeen: lastSeen == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(lastSeen),
      removed: removed,
    );
  }

  void _applyPresence(List<String> ids) {
    final now = DateTime.now();
    final next = ids.toSet();
    for (final id in online.value.difference(next)) {
      db.upsertMember(id, lastSeen: now, notify: false);
    }
    online.value = next;
  }

  Future<void> _applyConversation(Map<String, dynamic> json) async {
    final id = json['id'] as String;
    var name = db.conversation(id)?.name ?? 'Group';
    final meta = json['meta'] as String?;
    if (meta != null) {
      try {
        final decoded = await _crypto!.decryptMeta(id, meta);
        name = decoded['name'] as String? ?? name;
      } catch (e) {
        debugPrint('Could not read group $id: $e');
      }
    }
    db.upsertConversation(
      id: id,
      type: ConversationType.group,
      name: name,
      members: (json['members'] as List).cast<String>(),
      createdBy: json['createdBy'] as String?,
    );
  }

  void _bumpSeq(int seq) {
    if (_syncing) {
      _liveMaxSeq = max(_liveMaxSeq, seq);
    } else if (seq > db.getInt(Keys.lastSeq)) {
      db.setValue(Keys.lastSeq, '$seq');
    }
  }

  Future<void> _handleBatch(Map<String, dynamic> data) async {
    for (final msg in (data['msgs'] as List).cast<Map<String, dynamic>>()) {
      await _applyMessage(msg, live: false);
    }
    final upTo = data['upTo'] as int;
    final done = data['done'] as bool;
    final last = db.getInt(Keys.lastSeq);
    final next = done ? max(upTo, _liveMaxSeq) : upTo;
    if (next > last) db.setValue(Keys.lastSeq, '$next');
    if (done) {
      _syncing = false;
      if (_syncNewMessages > 0 && !appInForeground && _notificationsOn) {
        await notifications.showMessage(
          conversationId: kFamilyConversationId,
          title: db.getValue(Keys.familyName) ?? 'FamNest',
          body: _syncNewMessages == 1
              ? '1 new message'
              : '$_syncNewMessages new messages',
        );
      }
    }
  }

  bool get _notificationsOn => db.getBool(Keys.notifications, true);

  Uint8List? _agreementKeyOf(String deviceId) => deviceId == myId
      ? keys.agreementPublicKey
      : db.member(deviceId)?.agreementKey;

  void _ensureConversation(String conversationId) {
    if (conversationId == kFamilyConversationId) {
      db.ensureFamilyConversation(db.getValue(Keys.familyName) ?? 'Family');
      return;
    }
    final direct = directConversationMembers(conversationId);
    if (direct != null) {
      if (db.conversation(conversationId) == null) {
        db.upsertConversation(
          id: conversationId,
          type: ConversationType.direct,
          members: direct,
        );
      }
      return;
    }
    if (db.conversation(conversationId) == null) {
      db.upsertConversation(
        id: conversationId,
        type: ConversationType.group,
        name: 'Group',
      );
    }
  }

  Future<void> _applyMessage(
    Map<String, dynamic> json, {
    required bool live,
  }) async {
    final id = json['id'] as String;
    final conv = json['conv'] as String;
    final from = json['from'] as String;
    final seq = json['seq'] as int;
    _bumpSeq(seq);

    if (json['deleted'] == true) {
      final path = db.markDeleted(id);
      _deleteFile(path);
      db.refreshPreview(conv);
      return;
    }

    final existing = db.message(id);
    if (existing != null) {
      if (existing.status != MessageStatus.sent) {
        db.markSent(
          id,
          seq: seq,
          timestamp: DateTime.fromMillisecondsSinceEpoch(json['ts'] as int),
        );
      }
      return;
    }

    _ensureConversation(conv);
    String? text;
    Attachment? attachment;
    var kind = MessageKind.text;
    Map<String, dynamic>? payload;
    String? ref;
    try {
      final key = await _crypto!.keyFor(conv, _agreementKeyOf);
      final body = await _crypto!.decryptBody(
        json['body'] as String,
        id: id,
        conversationId: conv,
        sender: from,
        key: key,
      );
      text = body['text'] as String?;
      final att = body['att'];
      if (att is Map<String, dynamic>) attachment = Attachment.fromJson(att);
      kind = MessageKind.parse(body['kind']);
      final data = body['data'];
      if (data is Map<String, dynamic>) payload = data;
      ref = body['ref'] as String?;
    } catch (e) {
      debugPrint('Could not decrypt message $id: $e');
      text = '\u{26A0}\u{FE0F} This message could not be decrypted on this device.';
    }

    final message = ChatMessage(
      id: id,
      conversationId: conv,
      sender: from,
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['ts'] as int),
      status: MessageStatus.sent,
      text: text,
      attachment: attachment,
      deleted: false,
      localPath: null,
      transfer: TransferState.none,
      kind: kind,
      payload: payload,
      ref: ref,
    );

    if (kind.isResponse) {
      // Only accept responses to a poll/call in the same conversation.
      final target = ref == null ? null : db.message(ref);
      final expected = kind == MessageKind.rsvp
          ? MessageKind.call
          : MessageKind.poll;
      if (target == null ||
          target.conversationId != conv ||
          target.kind != expected) {
        return;
      }
      if (!db.insertMessage(message)) return;
      if (live &&
          from != myId &&
          kind == MessageKind.rsvp &&
          target.sender == myId &&
          _notificationsOn &&
          !(db.conversation(conv)?.muted ?? false)) {
        final name = _senderName(from);
        final answer = CallAnswer.parse(payload?['answer']);
        final label = answer == null
            ? (payload?['label'] as String? ?? '')
            : NotificationService.answerLabel(answer);
        unawaited(
          notifications.showMessage(
            conversationId: conv,
            title: '${target.call?.type.emoji ?? ''} ${target.call?.title ?? ''}'
                .trim(),
            body: '$name: ${answer?.emoji ?? ''} $label',
          ),
        );
      }
      return;
    }

    if (!db.insertMessage(message)) return;

    if (from != myId) {
      final visible = appInForeground && activeConversationId == conv;
      final conversation = db.conversation(conv);
      final muted = conversation?.muted ?? false;
      if (!visible) db.incrementUnread(conv);
      if (live && _notificationsOn) {
        // Family calls always alert (even in a muted or open chat): they are
        // meant to get everyone's attention. Polls alert unless muted.
        if (kind == MessageKind.call) {
          unawaited(_notifyCall(message));
        } else if (kind == MessageKind.poll && !muted) {
          unawaited(_notifyPoll(message));
        } else if (!visible && !muted) {
          unawaited(_notify(message, conversation));
        }
      } else if (!live && !visible && !muted) {
        _syncNewMessages++;
      }
    }
    db.refreshPreview(conv);

    if (attachment != null &&
        attachment.isImage &&
        attachment.size <= 15 * 1024 * 1024) {
      unawaited(download(message).catchError((Object _) {}));
    }
  }

  String _senderName(String id) =>
      db.member(id)?.displayName ?? NotificationService.l10n.familyMember;

  Future<void> _notifyCall(ChatMessage message) {
    final call = message.call!;
    return notifications.showCall(
      conversationId: message.conversationId,
      messageId: message.id,
      sender: _senderName(message.sender),
      call: CallData(
        type: call.type,
        // Built-in calls are shown in this device's language.
        title: call.type == CallType.custom
            ? call.title
            : NotificationService.callTitle(call.type),
        note: call.note,
      ),
    );
  }

  Future<void> _notifyPoll(ChatMessage message) => notifications.showPoll(
    conversationId: message.conversationId,
    messageId: message.id,
    sender: _senderName(message.sender),
    question: message.poll!.question,
  );

  /// Handles a tap on a notification's answer button.
  void answerFromNotification(String messageId, CallAnswer answer) {
    final call = db.message(messageId);
    if (call == null || call.kind != MessageKind.call || call.deleted) return;
    respondToCall(call, answer, NotificationService.answerLabel(answer));
    unawaited(notifications.clearMessage(messageId));
  }

  Future<void> _notify(ChatMessage message, Conversation? conversation) {
    final sender = db.member(message.sender)?.displayName ?? 'Family member';
    final title = switch (conversation?.type) {
      ConversationType.direct => sender,
      ConversationType.group => '$sender · ${conversation!.name}',
      _ => '$sender · ${db.getValue(Keys.familyName) ?? 'Family'}',
    };
    return notifications.showMessage(
      conversationId: message.conversationId,
      title: title,
      body: LocalDatabase.previewOf(message),
    );
  }

  void _handleAck(Map<String, dynamic> data) {
    final id = data['id'] as String;
    final seq = data['seq'] as int;
    db.markSent(
      id,
      seq: seq,
      timestamp: DateTime.fromMillisecondsSinceEpoch(data['ts'] as int),
    );
    _bumpSeq(seq);
    final conv = db.message(id)?.conversationId;
    if (conv != null) db.refreshPreview(conv);
    final waiter = _ackWaiters.remove(id);
    if (waiter != null && !waiter.isCompleted) waiter.complete();
  }

  void _handleError(Map<String, dynamic> data) {
    final ref = data['ref'] as String?;
    final code = data['code'] as String?;
    debugPrint('Hub error: $code ($ref)');
    if (ref == null) return;
    final waiter = _ackWaiters.remove(ref);
    if (waiter != null) {
      db.setStatus(ref, MessageStatus.failed);
      if (!waiter.isCompleted) {
        waiter.completeError(TransferException('Hub refused message: $code'));
      }
    }
    _uploads[ref]?.fail(TransferException('Hub refused file: $code'));
  }

  void _handleTyping(String conv, String from) {
    final timers = _typingTimers.putIfAbsent(conv, () => {});
    timers[from]?.cancel();
    timers[from] = Timer(const Duration(seconds: 5), () {
      timers.remove(from);
      _publishTyping();
    });
    _publishTyping();
  }

  void _publishTyping() {
    typing.value = {
      for (final entry in _typingTimers.entries)
        if (entry.value.isNotEmpty) entry.key: entry.value.keys.toSet(),
    };
  }

  // -- files -----------------------------------------------------------------

  Future<void> _handleChunk(ChunkFrame chunk) async {
    final download = _downloads[chunk.fileId];
    if (download == null || download.done.isCompleted) return;
    try {
      if (chunk.index != download.received) {
        throw const TransferException('File chunks arrived out of order');
      }
      final plain = await openWithCounter(chunk.data, download.key, chunk.index);
      download.sink.add(plain);
      download.received++;
      final total = download.expected > 0
          ? download.expected
          : chunkCountFor(download.attachment.size);
      if (download.received % 4 == 0 || download.received == total) {
        await _channel.sendJson({
          't': Msg.fileAck,
          'fileId': chunk.fileId,
          'n': download.received,
        });
      }
      _setProgress(download.messageId, download.received / total);
      if (download.received == total) {
        await download.sink.flush();
        download.done.complete();
      }
    } catch (e) {
      download.fail(e);
    }
  }

  void _setProgress(String messageId, double? value) {
    final next = Map<String, double>.of(progress.value);
    if (value == null) {
      next.remove(messageId);
    } else {
      next[messageId] = value;
    }
    progress.value = next;
  }

  Future<String> _storagePathFor(String messageId, String name) async {
    final safe = name.replaceAll(RegExp(r'[^\w.\- ]'), '_');
    final dir = Directory(p.join(filesDirectory, messageId));
    await dir.create(recursive: true);
    return p.join(dir.path, safe.isEmpty ? 'file' : safe);
  }

  void _deleteFile(String? path) {
    if (path == null) return;
    try {
      final dir = File(path).parent;
      if (p.isWithin(filesDirectory, dir.path)) {
        dir.deleteSync(recursive: true);
      } else {
        File(path).deleteSync();
      }
    } catch (_) {}
  }

  /// Downloads and decrypts an attachment into this device's storage.
  Future<void> download(ChatMessage message) async {
    final attachment = message.attachment;
    if (attachment == null || message.deleted) return;
    if (message.localPath != null && File(message.localPath!).existsSync()) {
      return;
    }
    if (_downloads.containsKey(attachment.fileId)) return;
    final channel = _channel;
    final destination = await _storagePathFor(message.id, attachment.name);
    final temp = File('$destination.part');
    final download = _Download(
      message.id,
      attachment,
      temp,
      temp.openWrite(),
      SecretKey(unb64(attachment.key)),
    );
    _downloads[attachment.fileId] = download;
    db.setTransfer(message.id, TransferState.active);
    _setProgress(message.id, 0);
    try {
      await channel.sendJson({'t': Msg.fileGet, 'fileId': attachment.fileId});
      await download.done.future;
      await download.sink.close();
      await temp.rename(destination);
      db.setTransfer(message.id, TransferState.done, localPath: destination);
    } catch (e) {
      await download.sink.close().catchError((Object _) {});
      if (temp.existsSync()) temp.deleteSync();
      db.setTransfer(message.id, TransferState.failed);
      rethrow;
    } finally {
      _downloads.remove(attachment.fileId);
      _setProgress(message.id, null);
    }
  }

  Future<void> _resumeDownloads() async {
    // Images that were interrupted by a dropped connection.
    for (final conv in db.conversations()) {
      for (final message in db.mediaMessages(conv.id)) {
        final attachment = message.attachment!;
        if (message.sender != myId &&
            attachment.isImage &&
            message.transfer == TransferState.active &&
            message.localPath == null) {
          unawaited(download(message).catchError((Object _) {}));
        }
      }
    }
  }

  Future<void> _upload(ChatMessage message, String path) async {
    final attachment = message.attachment!;
    final channel = _channel;
    final upload = _Upload(attachment.fileId);
    _uploads[attachment.fileId] = upload;
    db.setTransfer(message.id, TransferState.active);
    _setProgress(message.id, 0);
    final key = SecretKey(unb64(attachment.key));
    try {
      await channel.sendJson({
        't': Msg.filePut,
        'fileId': attachment.fileId,
        'size': attachment.size,
      });
      final file = await File(path).open();
      try {
        final chunks = chunkCountFor(attachment.size);
        for (var i = 0; i < chunks; i++) {
          while (i - upload.acked >= kFileWindow &&
              upload.error == null &&
              !upload.done.isCompleted) {
            await upload.changed.wait();
          }
          if (upload.error != null) throw upload.error!;
          if (upload.done.isCompleted) break; // Hub already had the file.
          final data = await file.read(kFileChunkSize);
          await channel.sendChunk(
            attachment.fileId,
            i,
            await sealWithCounter(data, key, i),
          );
          _setProgress(message.id, (i + 1) / chunks);
        }
      } finally {
        await file.close();
      }
      await upload.done.future.timeout(const Duration(minutes: 2));
      db.setTransfer(message.id, TransferState.done);
    } catch (e) {
      db.setTransfer(message.id, TransferState.none);
      rethrow;
    } finally {
      _uploads.remove(attachment.fileId);
      _setProgress(message.id, null);
    }
  }

  // -- outgoing --------------------------------------------------------------

  Future<void> _flushOutbox() async {
    if (_flushing) {
      _flushAgain = true;
      return;
    }
    _flushing = true;
    try {
      do {
        _flushAgain = false;
        for (final message in db.pendingMessages()) {
          if (_connection == null) return;
          await _deliver(message);
        }
      } while (_flushAgain);
    } catch (e) {
      debugPrint('Outbox paused: $e');
    } finally {
      _flushing = false;
    }
  }

  Future<void> _deliver(ChatMessage message) async {
    final crypto = _crypto;
    if (crypto == null) throw const TransferException('Not ready');
    final attachment = message.attachment;
    if (attachment != null && message.transfer != TransferState.done) {
      final path = message.localPath;
      if (path == null || !File(path).existsSync()) {
        db.setStatus(message.id, MessageStatus.failed);
        return;
      }
      await _upload(message, path);
    }

    final SecretKey key;
    try {
      key = await crypto.keyFor(message.conversationId, _agreementKeyOf);
    } catch (e) {
      db.setStatus(message.id, MessageStatus.failed);
      return;
    }
    final body = await crypto.encryptBody(
      {
        'text': ?message.text,
        'att': ?attachment?.toJson(),
        if (message.kind != MessageKind.text) 'kind': message.kind.name,
        'data': ?message.payload,
        'ref': ?message.ref,
      },
      id: message.id,
      conversationId: message.conversationId,
      sender: myId,
      key: key,
    );
    final waiter = Completer<void>();
    _ackWaiters[message.id] = waiter;
    await _channel.sendJson({
      't': Msg.send,
      'id': message.id,
      'conv': message.conversationId,
      'body': body,
    });
    try {
      await waiter.future.timeout(const Duration(seconds: 30));
    } on TransferException catch (e) {
      // Refused by the hub: already marked failed, continue with the rest.
      debugPrint('$e');
    }
  }

  void _queue(ChatMessage message) {
    db.insertMessage(message);
    db.refreshPreview(message.conversationId);
    if (_connection != null) unawaited(_flushOutbox());
  }

  Future<void> sendText(String conversationId, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _queue(
      ChatMessage(
        id: const Uuid().v4(),
        conversationId: conversationId,
        sender: myId,
        timestamp: DateTime.now(),
        status: MessageStatus.pending,
        text: trimmed,
        attachment: null,
        deleted: false,
        localPath: null,
        transfer: TransferState.none,
      ),
    );
  }

  void _queueKind(
    String conversationId,
    MessageKind kind,
    Map<String, dynamic> payload, {
    String? ref,
  }) {
    _queue(
      ChatMessage(
        id: const Uuid().v4(),
        conversationId: conversationId,
        sender: myId,
        timestamp: DateTime.now(),
        status: MessageStatus.pending,
        text: null,
        attachment: null,
        deleted: false,
        localPath: null,
        transfer: TransferState.none,
        kind: kind,
        payload: payload,
        ref: ref,
      ),
    );
  }

  /// Starts a poll. Members vote with [vote]; the author can [closePoll].
  void sendPoll(String conversationId, PollData poll) {
    final options = poll.options
        .map((o) => o.trim())
        .where((o) => o.isNotEmpty)
        .toList();
    if (poll.question.trim().isEmpty || options.length < 2) {
      throw ArgumentError('A poll needs a question and two options');
    }
    _queueKind(
      conversationId,
      MessageKind.poll,
      PollData(
        question: poll.question.trim(),
        options: options.take(12).toList(),
        multiple: poll.multiple,
      ).toJson(),
    );
  }

  /// Replaces this device's vote. An empty [choices] withdraws it.
  void vote(ChatMessage poll, Set<int> choices) => _queueKind(
    poll.conversationId,
    MessageKind.vote,
    {'choices': (choices.toList()..sort())},
    ref: poll.id,
  );

  void closePoll(ChatMessage poll) {
    if (poll.sender != myId) return;
    _queueKind(poll.conversationId, MessageKind.close, {}, ref: poll.id);
  }

  /// Calls the family ("Lunch is ready!"). [call.title] is the text shown in
  /// previews and notifications.
  void sendCall(String conversationId, CallData call) =>
      _queueKind(conversationId, MessageKind.call, call.toJson());

  /// Answers a family call. [label] is the localised answer text shown in
  /// the caller's notification.
  void respondToCall(ChatMessage call, CallAnswer answer, String label) =>
      _queueKind(
        call.conversationId,
        MessageKind.rsvp,
        {'answer': answer.name, 'label': label},
        ref: call.id,
      );

  /// Queues a photo or file. The file is copied into app storage so it stays
  /// available on this device and can be re-sent after reconnecting.
  Future<void> sendFile(
    String conversationId,
    File source, {
    String? name,
    String? caption,
    bool? asImage,
  }) async {
    final size = await source.length();
    if (size > kMaxFileSize) {
      throw const TransferException(
        'Files must be smaller than ${kMaxFileSize ~/ (1024 * 1024)} MB',
      );
    }
    final id = const Uuid().v4();
    final fileName = name ?? p.basename(source.path);
    final mime = lookupMimeType(fileName) ?? 'application/octet-stream';
    final destination = await _storagePathFor(id, fileName);
    await source.copy(destination);

    final isImage = asImage ?? mime.startsWith('image/');
    String? thumbnail;
    int? width;
    int? height;
    if (isImage) {
      final info = await _imageInfo(File(destination));
      thumbnail = info?.thumbnail;
      width = info?.width;
      height = info?.height;
    }
    final text = caption?.trim();
    _queue(
      ChatMessage(
        id: id,
        conversationId: conversationId,
        sender: myId,
        timestamp: DateTime.now(),
        status: MessageStatus.pending,
        text: text == null || text.isEmpty ? null : text,
        attachment: Attachment(
          fileId: randomId(),
          name: fileName,
          size: size,
          mime: mime,
          key: b64(randomBytes(32)),
          isImage: isImage && width != null,
          thumbnail: thumbnail,
          width: width,
          height: height,
        ),
        deleted: false,
        localPath: destination,
        transfer: TransferState.none,
      ),
    );
  }

  static Future<({String thumbnail, int width, int height})?> _imageInfo(
    File file,
  ) async {
    try {
      final bytes = await file.readAsBytes();
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      final width = descriptor.width;
      final height = descriptor.height;
      final codec = await descriptor.instantiateCodec(
        targetWidth: width >= height ? 24 : null,
        targetHeight: height > width ? 24 : null,
      );
      final frame = await codec.getNextFrame();
      final png = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      frame.image.dispose();
      codec.dispose();
      descriptor.dispose();
      buffer.dispose();
      if (png == null) return null;
      return (
        thumbnail: b64(png.buffer.asUint8List()),
        width: width,
        height: height,
      );
    } catch (_) {
      return null;
    }
  }

  void retry(ChatMessage message) {
    db.setStatus(message.id, MessageStatus.pending);
    if (_connection != null) unawaited(_flushOutbox());
  }

  Future<void> deleteForEveryone(ChatMessage message) async {
    if (message.status != MessageStatus.sent) {
      return deleteForMe(message);
    }
    await _channel.sendJson({'t': Msg.delete, 'id': message.id});
  }

  Future<void> deleteForMe(ChatMessage message) async {
    _deleteFile(db.removeLocally(message.id));
  }

  Future<void> clearConversation(String conversationId) async {
    for (final path in db.clearConversation(conversationId)) {
      _deleteFile(path);
    }
  }

  void markRead(String conversationId) {
    db.markRead(conversationId);
    unawaited(notifications.clear(conversationId));
  }

  void notifyTyping(String conversationId) {
    final last = _lastTypingSent[conversationId];
    final now = DateTime.now();
    if (last != null && now.difference(last) < const Duration(seconds: 3)) {
      return;
    }
    _lastTypingSent[conversationId] = now;
    final connection = _connection;
    if (connection == null) return;
    unawaited(
      connection.channel
          .sendJson({'t': Msg.typing, 'conv': conversationId})
          .catchError((Object _) {}),
    );
  }

  // -- profile & conversations ---------------------------------------------

  Future<void> _publishProfile() async {
    final me = db.member(myId);
    final crypto = _crypto;
    if (me == null || crypto == null) return;
    final avatar = me.avatar;
    final blob = await crypto.encryptProfile({
      'name': me.name,
      'avatar': avatar == null ? null : b64(avatar),
    });
    await _channel.sendJson({'t': Msg.profile, 'profile': blob});
    db.setBool(Keys.profileDirty, false);
  }

  Future<void> updateProfile({
    required String name,
    Uint8List? avatar,
    bool removeAvatar = false,
  }) async {
    db
      ..upsertMember(
        myId,
        name: name.trim(),
        avatar: avatar,
        clearAvatar: removeAvatar,
        agreementKey: keys.agreementPublicKey,
      )
      ..setBool(Keys.profileDirty, true);
    if (_connection != null) {
      await _publishProfile().catchError((Object _) {});
    }
  }

  /// Returns the id of the direct conversation with [peerId], creating it
  /// locally if needed.
  String openDirect(String peerId) {
    final id = directConversationId(myId, peerId);
    if (db.conversation(id) == null) {
      db.upsertConversation(
        id: id,
        type: ConversationType.direct,
        members: [myId, peerId],
      );
    }
    return id;
  }

  Future<String> createGroup(String name, Set<String> memberIds) async {
    final id = 'grp-${randomId(12)}';
    await _saveGroup(id, name, {...memberIds, myId});
    return id;
  }

  Future<void> updateGroup(String id, String name, Set<String> memberIds) =>
      _saveGroup(id, name, memberIds);

  Future<void> leaveGroup(String id) async {
    final conv = db.conversation(id);
    if (conv == null) return;
    await _saveGroup(
      id,
      conv.name,
      conv.members.where((m) => m != myId).toSet(),
    );
  }

  Future<void> _saveGroup(String id, String name, Set<String> members) async {
    final crypto = _crypto;
    if (crypto == null) {
      throw const TransferException('Connect to the family hub first');
    }
    final channel = _channel;
    final meta = await crypto.encryptMeta(id, {'name': name.trim()});
    await channel.sendJson({
      't': Msg.conversationUpsert,
      'id': id,
      'members': members.toList(),
      'meta': meta,
    });
    db.upsertConversation(
      id: id,
      type: ConversationType.group,
      name: name.trim(),
      members: members.toList(),
      createdBy: db.conversation(id)?.createdBy ?? myId,
    );
  }
}
