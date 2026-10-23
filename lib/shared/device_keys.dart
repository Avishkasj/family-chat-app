import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'crypto.dart';

/// Long-term keys of one device: Ed25519 for identity, X25519 for direct
/// (end-to-end) message encryption.
class DeviceKeys {
  DeviceKeys._({
    required this.signing,
    required this.agreement,
    required this.signingPublicKey,
    required this.agreementPublicKey,
    required this.deviceId,
  });

  final SimpleKeyPair signing;
  final SimpleKeyPair agreement;
  final Uint8List signingPublicKey;
  final Uint8List agreementPublicKey;
  final String deviceId;

  static Future<DeviceKeys> fromSeeds({
    required List<int> signingSeed,
    required List<int> agreementSeed,
  }) async {
    final signing = await Ed25519().newKeyPairFromSeed(signingSeed);
    final agreement = await X25519().newKeyPairFromSeed(agreementSeed);
    final signingPublic = await signing.extractPublicKey();
    final agreementPublic = await agreement.extractPublicKey();
    return DeviceKeys._(
      signing: signing,
      agreement: agreement,
      signingPublicKey: Uint8List.fromList(signingPublic.bytes),
      agreementPublicKey: Uint8List.fromList(agreementPublic.bytes),
      deviceId: await deviceIdFromSigningKey(signingPublic.bytes),
    );
  }

  Future<Uint8List> sign(List<int> message) async {
    final signature = await Ed25519().sign(message, keyPair: signing);
    return Uint8List.fromList(signature.bytes);
  }

  /// Raw X25519 shared secret with another device.
  Future<SecretKey> sharedSecretWith(List<int> remoteAgreementKey) {
    return X25519().sharedSecretKey(
      keyPair: agreement,
      remotePublicKey: SimplePublicKey(
        remoteAgreementKey,
        type: KeyPairType.x25519,
      ),
    );
  }
}
