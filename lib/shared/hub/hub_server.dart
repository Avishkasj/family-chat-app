import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../crypto.dart';
import '../handshake.dart';
import '../protocol.dart';
import '../secure_channel.dart';
import 'discovery_responder.dart';
import 'hub_store.dart';

typedef HubLogger = void Function(String message);

/// Snapshot of the hub's state, sent to the UI (possibly across isolates).
class HubStatus {
  const HubStatus({
    required this.running,
    required this.familyId,
    required this.familyName,
    required this.inviteCode,
    required this.port,
    required this.online,
    required this.memberCount,
  });

  factory HubStatus.fromJson(Map<String, dynamic> json) => HubStatus(
    running: json['running'] as bool? ?? false,
    familyId: json['familyId'] as String? ?? '',
    familyName: json['familyName'] as String? ?? '',
    inviteCode: json['inviteCode'] as String? ?? '',
    port: json['port'] as int? ?? kHubPort,
    online: (json['online'] as List? ?? const []).cast<String>(),
    memberCount: json['memberCount'] as int? ?? 0,
  );

  static const stopped = HubStatus(
    running: false,
    familyId: '',
    familyName: '',
    inviteCode: '',
    port: kHubPort,
    online: [],
    memberCount: 0,
  );

  final bool running;
  final String familyId;
  final String familyName;
  final String inviteCode;
  final int port;
  final List<String> online;
  final int memberCount;

  Map<String, dynamic> toJson() => {
    'running': running,
    'familyId': familyId,
    'familyName': familyName,
    'inviteCode': inviteCode,
    'port': port,
    'online': online,
    'memberCount': memberCount,
  };
}

class _Upload {
  _Upload(this.fileId, this.size, this.tempFile, this.sink);
  final String fileId;
  final int size;
  final File tempFile;
  final IOSink sink;
  int received = 0;
  int bytes = 0;

  int get chunks => chunkCountFor(size);
}

class _Download {
  _Download(this.fileId, this.size, this.file);
  final String fileId;
  final int size;
  final RandomAccessFile file;
  int sent = 0;
  int acked = 0;
  bool pumping = false;

  int get chunks => chunkCountFor(size);
}

class _Session {
  _Session(this.deviceId, this.channel);
  final String deviceId;
  final SecureChannel channel;
  final Map<String, _Upload> uploads = {};
  final Map<String, _Download> downloads = {};

  void send(Map<String, dynamic> data) {
    channel.sendJson(data).catchError((Object _) {});
  }
}

final RegExp _fileIdPattern = RegExp(r'^[a-f0-9]{32}$');
final RegExp _idPattern = RegExp(r'^[A-Za-z0-9_-]{8,64}$');

/// The family hub: authenticates devices, relays and stores encrypted
/// messages and files, and tracks presence. It never sees plaintext content.
class HubServer {
  HubServer(
    this.store, {
    this.port = kHubPort,
    this.onStatus,
    HubLogger? log,
    this.enableDiscoveryResponder = true,
  }) : _log = log ?? ((_) {});

  final HubStore store;
  final int port;
  final void Function(HubStatus status)? onStatus;
  final bool enableDiscoveryResponder;
  final HubLogger _log;

  HttpServer? _http;
  DiscoveryResponder? _discovery;
  final Map<String, _Session> _sessions = {};
  final Map<String, List<int>> _failedAttempts = {};

  bool get isRunning => _http != null;

  /// The port actually bound (differs from [port] when [port] is 0).
  int get boundPort => _http?.port ?? port;

  HubStatus get status => HubStatus(
    running: isRunning,
    familyId: store.familyId,
    familyName: store.familyName,
    inviteCode: store.inviteCode,
    port: boundPort,
    online: _sessions.keys.toList(),
    memberCount: store.activeMemberIds().length,
  );

  Future<void> start() async {
    if (isRunning) return;
    final http = await HttpServer.bind(InternetAddress.anyIPv4, port);
    http.idleTimeout = const Duration(seconds: 30);
    _http = http;
    http.listen(_handleRequest, onError: (Object e) => _log('http: $e'));

    if (enableDiscoveryResponder) {
      final discovery = DiscoveryResponder(
        describe: () => {
          'familyId': store.familyId,
          'familyName': store.familyName,
          'hubName': store.hubName,
          'port': boundPort,
        },
      );
      try {
        await discovery.start();
        _discovery = discovery;
      } catch (e) {
        _log('Discovery responder unavailable: $e');
      }
    }
    _log('Hub "${store.familyName}" listening on port $port');
    _emitStatus();
  }

  Future<void> stop() async {
    _discovery?.stop();
    _discovery = null;
    final sessions = _sessions.values.toList();
    _sessions.clear();
    await Future.wait(sessions.map((s) => s.channel.close()));
    await _http?.close(force: true);
    _http = null;
    _emitStatus();
  }

  /// Issues a new invite code and disconnects everyone. Devices must re-enter
  /// the new code; use this after removing a member.
  Future<String> rotateInviteCode() async {
    final code = store.rotateInviteCode();
    _emitStatus();
    // Give the hub owner's own device a moment to pick up the new code.
    await Future<void>.delayed(const Duration(milliseconds: 800));
    final sessions = _sessions.values.toList();
    _sessions.clear();
    await Future.wait(sessions.map((s) => s.channel.close()));
    _emitStatus();
    return code;
  }

  Future<void> removeMember(String deviceId) async {
    store.setRemoved(deviceId, removed: true);
    final session = _sessions.remove(deviceId);
    await session?.channel.close();
    final member = store.member(deviceId);
    if (member != null) _broadcast({'t': Msg.member, 'member': member.toJson()});
    _broadcastPresence();
    _emitStatus();
  }

  Future<void> renameFamily(String name) async {
    store.familyName = name;
    _emitStatus();
  }

  void _emitStatus() => onStatus?.call(status);

  // -- connection handling ---------------------------------------------------

  Future<void> _handleRequest(HttpRequest request) async {
    if (request.uri.path != kWebSocketPath ||
        !WebSocketTransformer.isUpgradeRequest(request)) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }
    final address = request.connectionInfo?.remoteAddress.address ?? '?';
    if (_isThrottled(address)) {
      request.response.statusCode = HttpStatus.tooManyRequests;
      await request.response.close();
      return;
    }
    try {
      final socket = await WebSocketTransformer.upgrade(request);
      await _handleSocket(socket, address);
    } catch (e) {
      _log('connection from $address failed: $e');
    }
  }

  bool _isThrottled(String address) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final attempts = _failedAttempts[address];
    if (attempts == null) return false;
    attempts.removeWhere((t) => now - t > 60000);
    return attempts.length >= 10;
  }

  void _recordFailure(String address) {
    _failedAttempts.putIfAbsent(address, () => []).add(
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> _handleSocket(WebSocket socket, String address) async {
    socket.pingInterval = kPingInterval;
    final incoming = StreamIterator<dynamic>(socket);
    _Session? session;
    try {
      final hubNonce = randomBytes(32);
      socket.add(
        jsonEncode({
          't': 'hello',
          'v': kProtocolVersion,
          'familyId': store.familyId,
          'familyName': store.familyName,
          'hubName': store.hubName,
          'nonce': b64(hubNonce),
        }),
      );
      if (!await incoming.moveNext().timeout(kHandshakeTimeout)) return;
      final raw = incoming.current;
      if (raw is! String || raw.length > 4096) return;
      final auth = jsonDecode(raw) as Map<String, dynamic>;
      if (auth['t'] != 'auth') return;

      Future<void> fail(String reason) async {
        _recordFailure(address);
        socket.add(jsonEncode({'t': 'auth_fail', 'reason': reason}));
        await socket.close(WebSocketStatus.policyViolation);
      }

      if (auth['v'] != kProtocolVersion) return fail(AuthFailure.version);
      final signKey = unb64(auth['signKey'] as String);
      final dhKey = unb64(auth['dhKey'] as String);
      final clientNonce = unb64(auth['nonce'] as String);
      if (signKey.length != 32 || dhKey.length != 32 || clientNonce.length != 32) {
        return fail(AuthFailure.identity);
      }

      final authKey = await deriveAuthKey(store.inviteCode, store.familyId);
      final transcript = clientTranscript(hubNonce, clientNonce, signKey, dhKey);
      final expectedMac = await hmacSha256(authKey, transcript);
      if (!constantTimeEquals(expectedMac, unb64(auth['mac'] as String))) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        return fail(AuthFailure.badCode);
      }
      final deviceId = await deviceIdFromSigningKey(signKey);
      if (deviceId != auth['deviceId'] ||
          !await verifyEd25519(transcript, unb64(auth['sig'] as String), signKey)) {
        return fail(AuthFailure.identity);
      }
      final existing = store.member(deviceId);
      if (existing != null && existing.removed) return fail(AuthFailure.removed);

      socket.add(
        jsonEncode({
          't': 'auth_ok',
          'mac': b64(
            await hmacSha256(authKey, hubTranscript(hubNonce, clientNonce)),
          ),
        }),
      );
      final keys = await deriveSessionKeys(authKey, hubNonce, clientNonce);
      final channel = SecureChannel(
        socket,
        incoming,
        sendKey: keys.hubToClient,
        receiveKey: keys.clientToHub,
      );

      final member = store.registerMember(
        id: deviceId,
        signKey: b64(signKey),
        dhKey: b64(dhKey),
      );
      session = _Session(deviceId, channel);
      final previous = _sessions[deviceId];
      _sessions[deviceId] = session;
      if (previous != null) unawaited(previous.channel.close());

      await _sendWelcome(session);
      if (existing == null || existing.dhKey != member.dhKey) {
        _broadcast({'t': Msg.member, 'member': member.toJson()});
      }
      _broadcastPresence();
      _emitStatus();
      _log('device $deviceId connected from $address');

      await for (final frame in channel.frames()) {
        await _handleFrame(session, frame);
      }
    } on TimeoutException {
      // Handshake timed out; nothing to clean up.
    } catch (e) {
      _log('session error: $e');
    } finally {
      final s = session;
      if (s != null) {
        await _cleanupSession(s);
        if (_sessions[s.deviceId] == s) {
          _sessions.remove(s.deviceId);
          store.touchMember(s.deviceId);
          _broadcastPresence();
          _emitStatus();
        }
      }
      if (socket.readyState == WebSocket.open) await socket.close();
    }
  }

  Future<void> _cleanupSession(_Session session) async {
    for (final upload in session.uploads.values) {
      await upload.sink.close().catchError((Object _) {});
      if (upload.tempFile.existsSync()) upload.tempFile.deleteSync();
    }
    session.uploads.clear();
    for (final download in session.downloads.values) {
      await download.file.close().catchError((Object _) => download.file);
    }
    session.downloads.clear();
  }

  Future<void> _sendWelcome(_Session session) {
    return session.channel.sendJson({
      't': Msg.welcome,
      'familyId': store.familyId,
      'familyName': store.familyName,
      'contentKey': store.contentKey,
      'you': session.deviceId,
      'members': store.members().map((m) => m.toJson()).toList(),
      'conversations': store
          .conversationsFor(session.deviceId)
          .map((c) => c.toJson())
          .toList(),
      'online': _sessions.keys.toList(),
      'latestSeq': store.latestSeq,
    });
  }

  void _broadcast(Map<String, dynamic> data, {Iterable<String>? to, String? except}) {
    for (final session in _sessions.values) {
      if (session.deviceId == except) continue;
      if (to != null && !to.contains(session.deviceId)) continue;
      session.send(data);
    }
  }

  void _broadcastPresence() => _broadcast({
    't': Msg.presence,
    'online': _sessions.keys.toList(),
  });

  // -- frames ----------------------------------------------------------------

  Future<void> _handleFrame(_Session session, ChannelFrame frame) async {
    switch (frame) {
      case ChunkFrame():
        await _handleChunk(session, frame);
      case JsonFrame():
        final data = frame.data;
        switch (frame.type) {
          case Msg.profile:
            _handleProfile(session, data);
          case Msg.send:
            _handleSend(session, data);
          case Msg.delete:
            _handleDelete(session, data);
          case Msg.sync:
            await _handleSync(session, data);
          case Msg.typing:
            _handleTyping(session, data);
          case Msg.conversationUpsert:
            _handleConversation(session, data);
          case Msg.filePut:
            await _handleFilePut(session, data);
          case Msg.fileGet:
            await _handleFileGet(session, data);
          case Msg.fileAck:
            await _handleDownloadAck(session, data);
        }
    }
  }

  void _error(_Session session, String code, [String? ref]) =>
      session.send({'t': Msg.error, 'code': code, 'ref': ?ref});

  void _handleProfile(_Session session, Map<String, dynamic> data) {
    final profile = data['profile'];
    if (profile is! String || profile.length > kMaxProfileBytes) {
      return _error(session, 'invalid_profile');
    }
    final member = store.updateProfile(session.deviceId, profile);
    _broadcast({'t': Msg.member, 'member': member.toJson()});
  }

  void _handleSend(_Session session, Map<String, dynamic> data) {
    final id = data['id'];
    final conv = data['conv'];
    final body = data['body'];
    if (id is! String || !_idPattern.hasMatch(id) || conv is! String) {
      return _error(session, 'invalid_message');
    }
    if (body is! String || body.length > kMaxBodyBytes) {
      return _error(session, 'invalid_message', id);
    }
    final recipients = store.recipientsOf(conv);
    if (recipients == null || !recipients.contains(session.deviceId)) {
      return _error(session, 'forbidden', id);
    }
    final existing = store.message(id);
    if (existing != null && existing.sender != session.deviceId) {
      return _error(session, 'invalid_message', id);
    }
    final message = store.insertMessage(
      id: id,
      conversationId: conv,
      sender: session.deviceId,
      body: body,
    );
    session.send({
      't': Msg.ack,
      'id': id,
      'seq': message.seq,
      'ts': message.timestamp,
    });
    if (existing == null) {
      _broadcast(
        {'t': Msg.message, 'msg': message.toJson()},
        to: recipients,
        except: session.deviceId,
      );
    }
  }

  void _handleDelete(_Session session, Map<String, dynamic> data) {
    final id = data['id'];
    if (id is! String) return;
    final message = store.deleteMessage(id, session.deviceId);
    if (message == null) return _error(session, 'forbidden', id);
    final recipients = store.recipientsOf(message.conversationId) ?? {};
    _broadcast(
      {'t': Msg.message, 'msg': message.toJson()},
      to: {...recipients, session.deviceId},
    );
  }

  Future<void> _handleSync(_Session session, Map<String, dynamic> data) async {
    var since = data['since'] is int ? data['since'] as int : 0;
    while (true) {
      final messages = store.messagesSince(session.deviceId, since);
      // Keep frames well below the size limit.
      final batch = <Map<String, dynamic>>[];
      var bytes = 0;
      for (final message in messages) {
        final json = message.toJson();
        bytes += (message.body?.length ?? 0) + 200;
        batch.add(json);
        since = message.seq;
        if (bytes > 1024 * 1024) break;
      }
      final done = batch.length == messages.length && messages.length < 200;
      await session.channel.sendJson({
        't': Msg.batch,
        'msgs': batch,
        'upTo': since,
        'done': done,
      });
      if (done) break;
    }
  }

  void _handleTyping(_Session session, Map<String, dynamic> data) {
    final conv = data['conv'];
    if (conv is! String) return;
    final recipients = store.recipientsOf(conv);
    if (recipients == null || !recipients.contains(session.deviceId)) return;
    _broadcast(
      {'t': Msg.typing, 'conv': conv, 'from': session.deviceId},
      to: recipients,
      except: session.deviceId,
    );
  }

  void _handleConversation(_Session session, Map<String, dynamic> data) {
    final id = data['id'];
    final members = data['members'];
    final meta = data['meta'];
    if (id is! String ||
        !_idPattern.hasMatch(id) ||
        members is! List ||
        members.length > 64 ||
        (meta != null && (meta is! String || meta.length > 16 * 1024))) {
      return _error(session, 'invalid_conversation');
    }
    final active = store.activeMemberIds();
    final memberIds = members.whereType<String>().where(active.contains).toSet();
    final existing = store.conversation(id);
    if (existing != null && !existing.members.contains(session.deviceId)) {
      return _error(session, 'forbidden', id);
    }
    if (existing == null && !memberIds.contains(session.deviceId)) {
      return _error(session, 'invalid_conversation', id);
    }
    final saved = store.saveConversation(
      id: id,
      members: memberIds.toList(),
      meta: meta as String?,
      createdBy: existing?.createdBy ?? session.deviceId,
    );
    _broadcast(
      {'t': Msg.conversation, 'conv': saved.toJson()},
      to: {...memberIds, ...?existing?.members},
    );
  }

  // -- files -----------------------------------------------------------------

  Future<void> _handleFilePut(_Session session, Map<String, dynamic> data) async {
    final fileId = data['fileId'];
    final size = data['size'];
    if (fileId is! String ||
        !_fileIdPattern.hasMatch(fileId) ||
        size is! int ||
        size < 0 ||
        size > kMaxFileSize) {
      return _error(session, 'invalid_file', fileId is String ? fileId : null);
    }
    if (store.fileSize(fileId) != null) {
      // Already uploaded (e.g. a retry after a dropped connection).
      return session.send({'t': Msg.fileOk, 'fileId': fileId});
    }
    if (session.uploads.length >= 4) return _error(session, 'busy', fileId);
    final temp = File('${store.filePath(fileId)}.part');
    session.uploads[fileId] = _Upload(fileId, size, temp, temp.openWrite());
  }

  Future<void> _handleChunk(_Session session, ChunkFrame chunk) async {
    final upload = session.uploads[chunk.fileId];
    if (upload == null) return;
    final isLast = chunk.index == upload.chunks - 1;
    final expectedLength = isLast
        ? encryptedSizeFor(upload.size) - upload.bytes
        : kEncryptedChunkSize;
    if (chunk.index != upload.received || chunk.data.length != expectedLength) {
      session.uploads.remove(upload.fileId);
      await upload.sink.close();
      if (upload.tempFile.existsSync()) upload.tempFile.deleteSync();
      return _error(session, 'invalid_file', upload.fileId);
    }
    upload.sink.add(chunk.data);
    upload.received++;
    upload.bytes += chunk.data.length;
    if (upload.received % 4 == 0 || isLast) {
      session.send({
        't': Msg.fileAck,
        'fileId': upload.fileId,
        'n': upload.received,
      });
    }
    if (isLast) {
      session.uploads.remove(upload.fileId);
      await upload.sink.close();
      await upload.tempFile.rename(store.filePath(upload.fileId));
      store.insertFile(upload.fileId, upload.size, session.deviceId);
      session.send({'t': Msg.fileOk, 'fileId': upload.fileId});
    }
  }

  Future<void> _handleFileGet(_Session session, Map<String, dynamic> data) async {
    final fileId = data['fileId'];
    if (fileId is! String || !_fileIdPattern.hasMatch(fileId)) return;
    final size = store.fileSize(fileId);
    final file = File(store.filePath(fileId));
    if (size == null || !file.existsSync()) {
      return session.send({'t': Msg.fileError, 'fileId': fileId});
    }
    final previous = session.downloads.remove(fileId);
    await previous?.file.close();
    final download = _Download(fileId, size, await file.open());
    session.downloads[fileId] = download;
    await session.channel.sendJson({
      't': Msg.fileInfo,
      'fileId': fileId,
      'size': size,
      'chunks': download.chunks,
    });
    await _pump(session, download);
  }

  Future<void> _handleDownloadAck(
    _Session session,
    Map<String, dynamic> data,
  ) async {
    final download = session.downloads[data['fileId']];
    final n = data['n'];
    if (download == null || n is! int) return;
    download.acked = max(download.acked, min(n, download.sent));
    if (download.acked >= download.chunks) {
      session.downloads.remove(download.fileId);
      await download.file.close();
      return;
    }
    await _pump(session, download);
  }

  Future<void> _pump(_Session session, _Download download) async {
    if (download.pumping) return;
    download.pumping = true;
    try {
      final total = encryptedSizeFor(download.size);
      while (download.sent < download.chunks &&
          download.sent - download.acked < kFileWindow) {
        final offset = download.sent * kEncryptedChunkSize;
        final length = min(kEncryptedChunkSize, total - offset);
        await download.file.setPosition(offset);
        final data = await download.file.read(length);
        await session.channel.sendChunk(download.fileId, download.sent, data);
        download.sent++;
      }
    } finally {
      download.pumping = false;
    }
  }
}
