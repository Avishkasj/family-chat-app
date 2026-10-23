import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'crypto.dart';
import 'device_keys.dart';
import 'protocol.dart';

/// End-to-end encryption of message content.
///
/// - Family and group chats use the family content key, which only devices
///   that authenticated with the invite code receive.
/// - Direct chats use a key derived from X25519 between the two devices, so
///   neither the hub nor other family members can read them.
///
/// Every ciphertext is bound (AEAD associated data) to its message id,
/// conversation and sender, so the hub can't move or re-attribute content.
class ContentCrypto {
  ContentCrypto({required this.familyKey, required this.keys});

  final SecretKey familyKey;
  final DeviceKeys keys;
  final Map<String, SecretKey> _directKeys = {};

  /// Returns the key for [conversationId]. For direct chats [peerAgreementKey]
  /// must resolve the other member's X25519 public key.
  Future<SecretKey> keyFor(
    String conversationId,
    Uint8List? Function(String deviceId) peerAgreementKey,
  ) async {
    final members = directConversationMembers(conversationId);
    if (members == null) return familyKey;
    final cached = _directKeys[conversationId];
    if (cached != null) return cached;
    final peer = members.firstWhere(
      (id) => id != keys.deviceId,
      orElse: () => throw StateError('Not a member of $conversationId'),
    );
    final peerKey = peerAgreementKey(peer);
    if (peerKey == null) throw StateError('Unknown key for $peer');
    final shared = await keys.sharedSecretWith(peerKey);
    final key = await Hkdf(hmac: Hmac.sha256(), outputLength: 32).deriveKey(
      secretKey: shared,
      nonce: utf8.encode(conversationId),
      info: utf8.encode('famnest/v1/direct'),
    );
    return _directKeys[conversationId] = key;
  }

  /// Forget cached direct keys (e.g. when a member's key changes).
  void clearCache() => _directKeys.clear();

  static List<int> _bodyAad(String id, String conv, String sender) =>
      utf8.encode('body|$id|$conv|$sender');

  Future<String> encryptBody(
    Map<String, dynamic> body, {
    required String id,
    required String conversationId,
    required String sender,
    required SecretKey key,
  }) async {
    final sealed = await sealBox(
      utf8.encode(jsonEncode(body)),
      key,
      aad: _bodyAad(id, conversationId, sender),
    );
    return b64(sealed);
  }

  Future<Map<String, dynamic>> decryptBody(
    String body, {
    required String id,
    required String conversationId,
    required String sender,
    required SecretKey key,
  }) async {
    final plain = await openBox(
      unb64(body),
      key,
      aad: _bodyAad(id, conversationId, sender),
    );
    return jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
  }

  Future<String> encryptProfile(Map<String, dynamic> profile) async => b64(
    await sealBox(
      utf8.encode(jsonEncode(profile)),
      familyKey,
      aad: utf8.encode('profile|${keys.deviceId}'),
    ),
  );

  Future<Map<String, dynamic>> decryptProfile(
    String blob,
    String deviceId,
  ) async {
    final plain = await openBox(
      unb64(blob),
      familyKey,
      aad: utf8.encode('profile|$deviceId'),
    );
    return jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
  }

  Future<String> encryptMeta(String conversationId, Map<String, dynamic> meta)
      async => b64(
    await sealBox(
      utf8.encode(jsonEncode(meta)),
      familyKey,
      aad: utf8.encode('meta|$conversationId'),
    ),
  );

  Future<Map<String, dynamic>> decryptMeta(
    String conversationId,
    String blob,
  ) async {
    final plain = await openBox(
      unb64(blob),
      familyKey,
      aad: utf8.encode('meta|$conversationId'),
    );
    return jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
  }
}
