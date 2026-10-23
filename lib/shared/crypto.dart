import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'protocol.dart';

final Random _random = Random.secure();

Uint8List randomBytes(int length) {
  final bytes = Uint8List(length);
  for (var i = 0; i < length; i++) {
    bytes[i] = _random.nextInt(256);
  }
  return bytes;
}

String randomId([int bytes = 16]) => hexEncode(randomBytes(bytes));

String b64(List<int> bytes) => base64Url.encode(bytes).replaceAll('=', '');

Uint8List unb64(String value) =>
    Uint8List.fromList(base64Url.decode(base64Url.normalize(value)));

String hexEncode(List<int> bytes) {
  final buffer = StringBuffer();
  for (final b in bytes) {
    buffer.write(b.toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}

bool constantTimeEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}

Uint8List concatBytes(List<List<int>> parts) {
  final builder = BytesBuilder(copy: false);
  for (final part in parts) {
    builder.add(part);
  }
  return builder.toBytes();
}

// ---------------------------------------------------------------------------
// Invite codes
// ---------------------------------------------------------------------------

/// Alphabet without look-alike characters (0/O, 1/I/L).
const String _inviteAlphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
const int _inviteLength = 16; // ~79 bits of entropy

String generateInviteCode() {
  final chars = List.generate(
    _inviteLength,
    (_) => _inviteAlphabet[_random.nextInt(_inviteAlphabet.length)],
  ).join();
  return formatInviteCode(chars);
}

String normalizeInviteCode(String input) =>
    input.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');

bool isValidInviteCode(String input) {
  final code = normalizeInviteCode(input);
  return code.length == _inviteLength &&
      code.split('').every(_inviteAlphabet.contains);
}

String formatInviteCode(String input) {
  final code = normalizeInviteCode(input);
  final groups = <String>[];
  for (var i = 0; i < code.length; i += 4) {
    groups.add(code.substring(i, min(i + 4, code.length)));
  }
  return groups.join('-');
}

// ---------------------------------------------------------------------------
// Key derivation
// ---------------------------------------------------------------------------

final Hmac _hmac = Hmac.sha256();

Future<SecretKey> deriveAuthKey(String inviteCode, String familyId) {
  return Hkdf(hmac: _hmac, outputLength: 32).deriveKey(
    secretKey: SecretKey(utf8.encode(normalizeInviteCode(inviteCode))),
    nonce: utf8.encode(familyId),
    info: utf8.encode('famnest/v1/auth'),
  );
}

Future<Uint8List> hmacSha256(SecretKey key, List<int> data) async {
  final mac = await _hmac.calculateMac(data, secretKey: key);
  return Uint8List.fromList(mac.bytes);
}

/// Directional session keys derived from the shared auth key and the two
/// handshake nonces.
Future<({SecretKey clientToHub, SecretKey hubToClient})> deriveSessionKeys(
  SecretKey authKey,
  List<int> hubNonce,
  List<int> clientNonce,
) async {
  final derived = await Hkdf(hmac: _hmac, outputLength: 64).deriveKey(
    secretKey: authKey,
    nonce: concatBytes([hubNonce, clientNonce]),
    info: utf8.encode('famnest/v1/session'),
  );
  final bytes = await derived.extractBytes();
  return (
    clientToHub: SecretKey(bytes.sublist(0, 32)),
    hubToClient: SecretKey(bytes.sublist(32, 64)),
  );
}

/// The device id is a fingerprint of the device's Ed25519 public key, so a
/// device can't claim another member's identity.
Future<String> deviceIdFromSigningKey(List<int> publicKey) async {
  final hash = await Sha256().hash(publicKey);
  return hexEncode(hash.bytes.sublist(0, 16));
}

Future<bool> verifyEd25519(
  List<int> message,
  List<int> signature,
  List<int> publicKey,
) async {
  try {
    return await Ed25519().verify(
      message,
      signature: Signature(
        signature,
        publicKey: SimplePublicKey(publicKey, type: KeyPairType.ed25519),
      ),
    );
  } catch (_) {
    return false;
  }
}

// ---------------------------------------------------------------------------
// AEAD helpers
// ---------------------------------------------------------------------------

final AesGcm aesGcm = AesGcm.with256bits();

/// Encrypts [plain] and returns nonce || ciphertext || tag.
Future<Uint8List> sealBox(
  List<int> plain,
  SecretKey key, {
  List<int> aad = const [],
}) async {
  final nonce = aesGcm.newNonce();
  final box = await aesGcm.encrypt(
    plain,
    secretKey: key,
    nonce: nonce,
    aad: aad,
  );
  return concatBytes([nonce, box.cipherText, box.mac.bytes]);
}

/// Reverses [sealBox]. Throws [SecretBoxAuthenticationError] on tampering.
Future<Uint8List> openBox(
  List<int> sealed,
  SecretKey key, {
  List<int> aad = const [],
}) async {
  if (sealed.length < 12 + kAeadTagLength) {
    throw const FormatException('Sealed box too short');
  }
  final box = SecretBox(
    sealed.sublist(12, sealed.length - kAeadTagLength),
    nonce: sealed.sublist(0, 12),
    mac: Mac(sealed.sublist(sealed.length - kAeadTagLength)),
  );
  return Uint8List.fromList(
    await aesGcm.decrypt(box, secretKey: key, aad: aad),
  );
}

/// Deterministic nonce for numbered frames / chunks (never reused per key).
List<int> counterNonce(int counter) {
  final nonce = Uint8List(12);
  ByteData.sublistView(nonce).setUint64(4, counter);
  return nonce;
}

Future<Uint8List> sealWithCounter(
  List<int> plain,
  SecretKey key,
  int counter,
) async {
  final box = await aesGcm.encrypt(
    plain,
    secretKey: key,
    nonce: counterNonce(counter),
  );
  return concatBytes([box.cipherText, box.mac.bytes]);
}

Future<Uint8List> openWithCounter(
  List<int> sealed,
  SecretKey key,
  int counter,
) async {
  if (sealed.length < kAeadTagLength) {
    throw const FormatException('Sealed chunk too short');
  }
  final box = SecretBox(
    sealed.sublist(0, sealed.length - kAeadTagLength),
    nonce: counterNonce(counter),
    mac: Mac(sealed.sublist(sealed.length - kAeadTagLength)),
  );
  return Uint8List.fromList(await aesGcm.decrypt(box, secretKey: key));
}
