import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:famnest/shared/content_crypto.dart';
import 'package:famnest/shared/crypto.dart';
import 'package:famnest/shared/device_keys.dart';
import 'package:famnest/shared/handshake.dart';
import 'package:famnest/shared/hub/hub_server.dart';
import 'package:famnest/shared/hub/hub_store.dart';
import 'package:famnest/shared/protocol.dart';
import 'package:famnest/shared/secure_channel.dart';
import 'package:flutter_test/flutter_test.dart';

/// Minimal test client: collects JSON frames and chunks from the hub.
class TestClient {
  TestClient._(this.connection) {
    _subscription = connection.channel.frames().listen(
      (frame) {
        if (frame is JsonFrame) {
          json.add(frame.data);
        } else if (frame is ChunkFrame) {
          chunks.add(frame);
        }
        _changes.add(null);
      },
      onError: (Object _) {},
      onDone: () => _changes.add(null),
    );
  }

  static Future<TestClient> connect(
    int port,
    String code,
    DeviceKeys keys,
  ) async => TestClient._(
    await connectToHub(
      host: '127.0.0.1',
      port: port,
      inviteCode: code,
      keys: keys,
    ),
  );

  final HubConnection connection;
  late final StreamSubscription<ChannelFrame> _subscription;
  final List<Map<String, dynamic>> json = [];
  final List<ChunkFrame> chunks = [];
  final StreamController<void> _changes = StreamController.broadcast();

  SecureChannel get channel => connection.channel;

  Future<Map<String, dynamic>> waitFor(
    String type, {
    bool Function(Map<String, dynamic>)? where,
  }) async {
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (true) {
      final index = json.indexWhere(
        (m) => m['t'] == type && (where == null || where(m)),
      );
      if (index >= 0) return json.removeAt(index);
      final remaining = deadline.difference(DateTime.now());
      if (remaining.isNegative) throw TimeoutException('waiting for $type');
      await _changes.stream.first.timeout(remaining, onTimeout: () {});
    }
  }

  Future<void> close() async {
    await channel.close();
    await _subscription.cancel();
  }
}

Future<DeviceKeys> newKeys() => DeviceKeys.fromSeeds(
  signingSeed: randomBytes(32),
  agreementSeed: randomBytes(32),
);

void main() {
  late Directory dir;
  late HubStore store;
  late HubServer server;
  late String code;
  late int port;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('famnest_hub_test');
    store = HubStore.open(dir.path);
    code = store.initialize(familyName: 'Test family', hubName: 'test');
    server = HubServer(store, port: 0, enableDiscoveryResponder: false);
    await server.start();
    port = server.boundPort;
  });

  tearDown(() async {
    await server.stop();
    store.close();
    await dir.delete(recursive: true);
  });

  test('invite codes are well formed and normalised', () {
    expect(isValidInviteCode(code), isTrue);
    expect(isValidInviteCode(code.toLowerCase().replaceAll('-', ' ')), isTrue);
    expect(isValidInviteCode('ABCD-EFGH'), isFalse);
  });

  test('wrong invite code is rejected', () async {
    final keys = await newKeys();
    await expectLater(
      connectToHub(
        host: '127.0.0.1',
        port: port,
        inviteCode: generateInviteCode(),
        keys: keys,
      ),
      throwsA(
        isA<HubAuthException>().having(
          (e) => e.reason,
          'reason',
          AuthFailure.badCode,
        ),
      ),
    );
  });

  test('messages relay, sync, and delete end-to-end encrypted', () async {
    final aliceKeys = await newKeys();
    final bobKeys = await newKeys();
    final alice = await TestClient.connect(port, code, aliceKeys);
    final welcome = await alice.waitFor(Msg.welcome);
    final familyKey = SecretKey(unb64(welcome['contentKey'] as String));
    final aliceCrypto = ContentCrypto(familyKey: familyKey, keys: aliceKeys);

    final bob = await TestClient.connect(port, code, bobKeys);
    await bob.waitFor(Msg.welcome);
    final bobCrypto = ContentCrypto(familyKey: familyKey, keys: bobKeys);

    // Family message
    const id = 'msg-0000001';
    final body = await aliceCrypto.encryptBody(
      {'text': 'Dinner is ready'},
      id: id,
      conversationId: kFamilyConversationId,
      sender: aliceKeys.deviceId,
      key: familyKey,
    );
    await alice.channel.sendJson({
      't': Msg.send,
      'id': id,
      'conv': kFamilyConversationId,
      'body': body,
    });
    final ack = await alice.waitFor(Msg.ack);
    expect(ack['id'], id);
    final received = await bob.waitFor(Msg.message);
    final msg = received['msg'] as Map<String, dynamic>;
    expect(msg['from'], aliceKeys.deviceId);
    final decrypted = await bobCrypto.decryptBody(
      msg['body'] as String,
      id: id,
      conversationId: kFamilyConversationId,
      sender: aliceKeys.deviceId,
      key: familyKey,
    );
    expect(decrypted['text'], 'Dinner is ready');

    // Direct message: keys agree on both sides, and hub only sees ciphertext.
    final dm = directConversationId(aliceKeys.deviceId, bobKeys.deviceId);
    Uint8List? lookup(String deviceId) => deviceId == aliceKeys.deviceId
        ? aliceKeys.agreementPublicKey
        : bobKeys.agreementPublicKey;
    final aliceDmKey = await aliceCrypto.keyFor(dm, lookup);
    final bobDmKey = await bobCrypto.keyFor(dm, lookup);
    expect(await aliceDmKey.extractBytes(), await bobDmKey.extractBytes());

    // Sync from scratch returns both stored messages for a reconnecting device.
    await bob.channel.sendJson({'t': Msg.sync, 'since': 0});
    final batch = await bob.waitFor(Msg.batch);
    expect((batch['msgs'] as List).length, 1);
    expect(batch['done'], isTrue);

    // Deleting re-sequences the message so later syncs see the deletion.
    await alice.channel.sendJson({'t': Msg.delete, 'id': id});
    final deleted = await bob.waitFor(Msg.message);
    expect((deleted['msg'] as Map)['deleted'], isTrue);
    expect((deleted['msg'] as Map)['seq'], greaterThan(ack['seq'] as int));

    // Bob may not delete Alice's message.
    await bob.channel.sendJson({'t': Msg.delete, 'id': id});
    expect((await bob.waitFor(Msg.error))['code'], 'forbidden');

    await alice.close();
    await bob.close();
  });

  test('group conversations only reach their members', () async {
    final a = await newKeys();
    final b = await newKeys();
    final c = await newKeys();
    final ca = await TestClient.connect(port, code, a);
    final cb = await TestClient.connect(port, code, b);
    final cc = await TestClient.connect(port, code, c);
    for (final client in [ca, cb, cc]) {
      await client.waitFor(Msg.welcome);
    }

    await ca.channel.sendJson({
      't': Msg.conversationUpsert,
      'id': 'group-123456',
      'members': [a.deviceId, b.deviceId],
      'meta': 'opaque',
    });
    await cb.waitFor(Msg.conversation);

    await cc.channel.sendJson({
      't': Msg.send,
      'id': 'msg-intruder',
      'conv': 'group-123456',
      'body': 'x',
    });
    expect((await cc.waitFor(Msg.error))['code'], 'forbidden');

    for (final client in [ca, cb, cc]) {
      await client.close();
    }
  });

  test('files upload and download in encrypted chunks', () async {
    final keys = await newKeys();
    final client = await TestClient.connect(port, code, keys);
    await client.waitFor(Msg.welcome);

    final fileKey = SecretKey(randomBytes(32));
    final plain = randomBytes(kFileChunkSize * 2 + 1234);
    final chunks = chunkCountFor(plain.length);
    final fileId = randomId();

    await client.channel.sendJson({
      't': Msg.filePut,
      'fileId': fileId,
      'size': plain.length,
    });
    for (var i = 0; i < chunks; i++) {
      final start = i * kFileChunkSize;
      final end = (start + kFileChunkSize).clamp(0, plain.length);
      final sealed = await sealWithCounter(
        plain.sublist(start, end),
        fileKey,
        i,
      );
      await client.channel.sendChunk(fileId, i, sealed);
    }
    await client.waitFor(Msg.fileOk);

    await client.channel.sendJson({'t': Msg.fileGet, 'fileId': fileId});
    final info = await client.waitFor(Msg.fileInfo);
    expect(info['chunks'], chunks);
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    var acked = 0;
    while (client.chunks.length < chunks && DateTime.now().isBefore(deadline)) {
      if (client.chunks.length > acked) {
        acked = client.chunks.length;
        await client.channel.sendJson({
          't': Msg.fileAck,
          'fileId': fileId,
          'n': acked,
        });
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    final builder = BytesBuilder();
    for (final chunk in client.chunks) {
      builder.add(await openWithCounter(chunk.data, fileKey, chunk.index));
    }
    expect(builder.toBytes(), plain);
    await client.close();
  });

  test('removed members are refused and invite rotation locks out old code', () async {
    final keys = await newKeys();
    final client = await TestClient.connect(port, code, keys);
    await client.waitFor(Msg.welcome);
    await server.removeMember(keys.deviceId);
    await expectLater(
      connectToHub(host: '127.0.0.1', port: port, inviteCode: code, keys: keys),
      throwsA(isA<HubAuthException>()),
    );

    final other = await newKeys();
    final newCode = await server.rotateInviteCode();
    await expectLater(
      connectToHub(host: '127.0.0.1', port: port, inviteCode: code, keys: other),
      throwsA(isA<HubAuthException>()),
    );
    final ok = await TestClient.connect(port, newCode, other);
    await ok.waitFor(Msg.welcome);
    await ok.close();
  });
}
