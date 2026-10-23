import 'dart:async';
import 'dart:io';

import 'package:famnest/data/local_database.dart';
import 'package:famnest/data/models.dart';
import 'package:famnest/data/secure_vault.dart';
import 'package:famnest/services/chat_service.dart';
import 'package:famnest/services/discovery_service.dart';
import 'package:famnest/services/notification_service.dart';
import 'package:famnest/shared/crypto.dart';
import 'package:famnest/shared/device_keys.dart';
import 'package:famnest/shared/hub/hub_server.dart';
import 'package:famnest/shared/hub/hub_store.dart';
import 'package:famnest/shared/protocol.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// In-memory replacement for the platform keystore.
class MemoryVault extends SecureVault {
  String? _code;

  @override
  Future<String?> inviteCode() async => _code;

  @override
  Future<void> setInviteCode(String? code) async =>
      _code = code == null ? null : normalizeInviteCode(code);

  @override
  Future<void> wipe() async => _code = null;
}

/// Records notifications instead of showing them.
class RecordingNotifications extends NotificationService {
  final List<String> shown = [];

  @override
  Future<void> showMessage({
    required String conversationId,
    required String title,
    required String body,
  }) async => shown.add('message:$body');

  @override
  Future<void> showPoll({
    required String conversationId,
    required String messageId,
    required String sender,
    required String question,
  }) async => shown.add('poll:$question');

  @override
  Future<void> showCall({
    required String conversationId,
    required String messageId,
    required String sender,
    required CallData call,
  }) async => shown.add('call:${call.title}');
}

class Device {
  Device._(this.chat, this.dir);

  RecordingNotifications get notifications =>
      chat.notifications as RecordingNotifications;

  static Future<Device> create(Directory root, String name) async {
    final dir = await Directory(p.join(root.path, name)).create();
    final keys = await DeviceKeys.fromSeeds(
      signingSeed: randomBytes(32),
      agreementSeed: randomBytes(32),
    );
    final db = LocalDatabase.open(p.join(dir.path, 'app.db'));
    db.upsertMember(keys.deviceId, agreementKey: keys.agreementPublicKey);
    final chat = ChatService(
      db: db,
      vault: MemoryVault(),
      keys: keys,
      discovery: DiscoveryService(),
      notifications: RecordingNotifications(),
      filesDirectory: p.join(dir.path, 'files'),
    );
    await chat.updateProfile(name: name);
    return Device._(chat, dir);
  }

  final ChatService chat;
  final Directory dir;

  LocalDatabase get db => chat.db;
  String get id => chat.myId;

  Future<void> join(HubStore store, int port) => chat.configure(
    host: '127.0.0.1',
    port: port,
    familyId: store.familyId,
    familyName: store.familyName,
    inviteCode: store.inviteCode,
    // Avoids network discovery in tests.
    isHubOwner: true,
  );
}

Future<void> eventually(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('Condition not met');
    }
    await Future<void>.delayed(const Duration(milliseconds: 25));
  }
}

void main() {
  late Directory root;
  late HubStore store;
  late HubServer server;
  late int port;
  final devices = <Device>[];

  setUp(() async {
    root = await Directory.systemTemp.createTemp('famnest_chat_test');
    store = HubStore.open(p.join(root.path, 'hub'));
    store.initialize(familyName: 'Perera Family', hubName: 'test');
    server = HubServer(store, port: 0, enableDiscoveryResponder: false);
    await server.start();
    port = server.boundPort;
  });

  tearDown(() async {
    for (final device in devices) {
      await device.chat.stop();
    }
    devices.clear();
    await server.stop();
    store.close();
    await root.delete(recursive: true);
  });

  Future<Device> device(String name) async {
    final d = await Device.create(root, name);
    devices.add(d);
    return d;
  }

  test('family chat, profiles, direct messages and deletion', () async {
    final mum = await device('Mum');
    final dad = await device('Dad');
    await mum.join(store, port);
    await dad.join(store, port);
    await eventually(
      () => mum.chat.link.value.isConnected && dad.chat.link.value.isConnected,
    );

    // Profiles are exchanged end-to-end encrypted.
    await eventually(() => dad.db.member(mum.id)?.name == 'Mum');
    await eventually(() => mum.db.member(dad.id)?.name == 'Dad');
    expect(store.member(mum.id)!.profile, isNot(contains('Mum')));

    await mum.chat.sendText(kFamilyConversationId, 'Dinner at 7');
    await eventually(
      () => dad.db.messages(kFamilyConversationId).any(
        (m) => m.text == 'Dinner at 7',
      ),
    );
    final sent = mum.db.messages(kFamilyConversationId).single;
    await eventually(
      () => mum.db.message(sent.id)!.status == MessageStatus.sent,
    );
    expect(dad.db.conversation(kFamilyConversationId)!.unread, 1);

    // Direct message: only ciphertext reaches the hub.
    final dm = mum.chat.openDirect(dad.id);
    await mum.chat.sendText(dm, 'Secret anniversary plan');
    await eventually(
      () => dad.db.messages(dm).any((m) => m.text == 'Secret anniversary plan'),
    );
    final stored = store.messagesSince(dad.id, 0).last;
    expect(stored.body, isNot(contains('anniversary')));

    // Delete for everyone.
    await eventually(
      () => mum.db.messages(dm).single.status == MessageStatus.sent,
    );
    await mum.chat.deleteForEveryone(mum.db.messages(dm).single);
    await eventually(() => dad.db.messages(dm).single.deleted);
    expect(dad.db.messages(dm).single.text, isNull);
  });

  test('messages sent while offline are delivered after reconnecting', () async {
    final mum = await device('Mum');
    final son = await device('Son');
    await mum.join(store, port);
    await son.join(store, port);
    await eventually(
      () => mum.chat.link.value.isConnected && son.chat.link.value.isConnected,
    );

    // Son goes offline; Mum keeps chatting.
    await son.chat.stop();
    await mum.chat.sendText(kFamilyConversationId, 'Are you home?');
    await mum.chat.sendText(kFamilyConversationId, 'Call me');

    // Hub goes down; Mum's next message waits in her outbox.
    await server.stop();
    await eventually(() => !mum.chat.link.value.isConnected);
    await mum.chat.sendText(kFamilyConversationId, 'Queued while hub was off');
    expect(
      mum.db.pendingMessages().map((m) => m.text),
      contains('Queued while hub was off'),
    );

    server = HubServer(store, port: port, enableDiscoveryResponder: false);
    await server.start();
    mum.chat.reconnectNow();
    son.chat.start();
    await eventually(
      () => son.db.messages(kFamilyConversationId).length == 3,
      timeout: const Duration(seconds: 20),
    );
    expect(
      son.db.messages(kFamilyConversationId).map((m) => m.text),
      ['Are you home?', 'Call me', 'Queued while hub was off'],
    );
    expect(mum.db.pendingMessages(), isEmpty);
  });

  test('files are shared encrypted and decrypted on download', () async {
    final mum = await device('Mum');
    final dad = await device('Dad');
    await mum.join(store, port);
    await dad.join(store, port);
    await eventually(
      () => mum.chat.link.value.isConnected && dad.chat.link.value.isConnected,
    );

    final source = File(p.join(root.path, 'report.pdf'));
    final content = randomBytes(kFileChunkSize * 3 + 77);
    await source.writeAsBytes(content);
    await mum.chat.sendFile(kFamilyConversationId, source, caption: 'Report');

    await eventually(
      () => dad.db.messages(kFamilyConversationId).any(
        (m) => m.attachment?.name == 'report.pdf',
      ),
      timeout: const Duration(seconds: 20),
    );
    final received = dad.db
        .messages(kFamilyConversationId)
        .firstWhere((m) => m.attachment != null);
    expect(received.text, 'Report');

    // The hub's copy is ciphertext.
    final hubCopy = File(store.filePath(received.attachment!.fileId));
    expect(await hubCopy.length(), encryptedSizeFor(content.length));

    await dad.chat.download(received);
    final local = dad.db.message(received.id)!;
    expect(local.transfer, TransferState.done);
    expect(await File(local.localPath!).readAsBytes(), content);
  });

  test('groups are created, synced and restricted to members', () async {
    final mum = await device('Mum');
    final dad = await device('Dad');
    final kid = await device('Kid');
    for (final d in [mum, dad, kid]) {
      await d.join(store, port);
    }
    await eventually(
      () => [mum, dad, kid].every((d) => d.chat.link.value.isConnected),
    );
    await eventually(() => mum.db.member(dad.id)?.agreementKey != null);

    final group = await mum.chat.createGroup('Surprise party', {dad.id});
    await eventually(() => dad.db.conversation(group)?.name == 'Surprise party');
    await mum.chat.sendText(group, 'Shh!');
    await eventually(() => dad.db.messages(group).isNotEmpty);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(kid.db.conversation(group), isNull);
    expect(kid.db.messages(group), isEmpty);
  });

  test('polls and family calls collect responses from everyone', () async {
    final mum = await device('Mum');
    final dad = await device('Dad');
    final kid = await device('Kid');
    for (final d in [mum, dad, kid]) {
      await d.join(store, port);
    }
    await eventually(
      () => [mum, dad, kid].every((d) => d.chat.link.value.isConnected),
    );

    // Poll: votes can change; votes after closing are ignored.
    mum.chat.sendPoll(
      kFamilyConversationId,
      const PollData(
        question: 'Where for the trip?',
        options: ['Kandy', 'Galle', ' '],
        multiple: false,
      ),
    );
    await eventually(
      () => dad.db.messages(kFamilyConversationId).any((m) => m.poll != null),
    );
    ChatMessage pollOn(Device d) =>
        d.db.messages(kFamilyConversationId).firstWhere((m) => m.poll != null);
    expect(pollOn(dad).poll!.options, ['Kandy', 'Galle']);

    dad.chat.vote(pollOn(dad), {0});
    kid.chat.vote(pollOn(kid), {0});
    kid.chat.vote(pollOn(kid), {1}); // changed mind
    PollTally tallyOn(Device d) =>
        PollTally.from(pollOn(d), d.db.responsesTo(pollOn(d).id));
    await eventually(() {
      final t = tallyOn(mum);
      return t.votersFor(0).length == 1 && t.votersFor(1).length == 1;
    });
    expect(tallyOn(mum).choicesOf(kid.id), {1});

    mum.chat.closePoll(pollOn(mum));
    await eventually(() => tallyOn(dad).closed);
    dad.chat.vote(pollOn(dad), {1});
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(tallyOn(kid).choicesOf(dad.id), {0});

    // Responses don't appear as chat bubbles or change the preview.
    expect(
      kid.db.messages(kFamilyConversationId).where((m) => m.kind.isResponse),
      isEmpty,
    );

    // Family call with RSVPs.
    mum.chat.sendCall(
      kFamilyConversationId,
      const CallData(type: CallType.lunch, title: 'Lunch is ready!'),
    );
    ChatMessage callOn(Device d) =>
        d.db.messages(kFamilyConversationId).firstWhere((m) => m.call != null);
    await eventually(
      () => kid.db.messages(kFamilyConversationId).any((m) => m.call != null),
    );
    expect(
      kid.db.conversation(kFamilyConversationId)!.lastPreview,
      contains('Lunch is ready!'),
    );
    kid.chat.respondToCall(callOn(kid), CallAnswer.coming, 'On my way');
    dad.chat.respondToCall(callOn(dad), CallAnswer.soon, 'In 5 minutes');
    await eventually(
      () => CallReplies.from(mum.db.responsesTo(callOn(mum).id)).answers.length == 2,
    );
    final replies = CallReplies.from(mum.db.responsesTo(callOn(mum).id));
    expect(replies.answers[kid.id], CallAnswer.coming);
    expect(replies.answers[dad.id], CallAnswer.soon);
  });

  test('polls and calls notify other members, even with the chat open', () async {
    final mum = await device('Mum');
    final dad = await device('Dad');
    await mum.join(store, port);
    await dad.join(store, port);
    await eventually(
      () => mum.chat.link.value.isConnected && dad.chat.link.value.isConnected,
    );
    await eventually(() => dad.db.member(mum.id)?.name == 'Mum');

    // Dad is looking at the family chat, which he has muted.
    dad.chat.activeConversationId = kFamilyConversationId;
    dad.db.setMuted(kFamilyConversationId, true);

    mum.chat.sendCall(
      kFamilyConversationId,
      const CallData(type: CallType.dinner, title: 'Dinner is ready!'),
    );
    await eventually(() => dad.notifications.shown.isNotEmpty);
    expect(dad.notifications.shown, ['call:Dinner is ready!']);

    // Polls respect mute but not an open chat.
    dad.db.setMuted(kFamilyConversationId, false);
    mum.chat.sendPoll(
      kFamilyConversationId,
      const PollData(question: 'Movie night?', options: ['Yes', 'No'], multiple: false),
    );
    await eventually(() => dad.notifications.shown.length == 2);
    expect(dad.notifications.shown.last, 'poll:Movie night?');

    // A regular message in the open chat doesn't notify; the sender never does.
    await mum.chat.sendText(kFamilyConversationId, 'hi');
    await eventually(
      () => dad.db.messages(kFamilyConversationId).any((m) => m.text == 'hi'),
    );
    expect(dad.notifications.shown.length, 2);
    expect(mum.notifications.shown, isEmpty);

    // Answering from the notification records an RSVP and notifies Mum.
    final call = dad.db
        .messages(kFamilyConversationId)
        .firstWhere((m) => m.call != null);
    dad.chat.answerFromNotification(call.id, CallAnswer.coming);
    await eventually(() => mum.notifications.shown.isNotEmpty);
    expect(mum.notifications.shown.single, contains('Dad'));
    expect(
      CallReplies.from(mum.db.responsesTo(call.id)).answers[dad.id],
      CallAnswer.coming,
    );
  });
}
