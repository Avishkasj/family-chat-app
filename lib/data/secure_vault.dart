import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../shared/crypto.dart';
import '../shared/device_keys.dart';

/// Device secrets kept in the platform keystore (Android Keystore / iOS
/// Keychain, "this device only" so they are never synced to a cloud).
class SecureVault {
  SecureVault([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );

  final FlutterSecureStorage _storage;

  static const _signingSeed = 'signing_seed';
  static const _agreementSeed = 'agreement_seed';
  static const _inviteCode = 'invite_code';

  /// Loads this device's identity keys, creating them on first launch.
  Future<DeviceKeys> loadOrCreateKeys() async {
    var signing = await _storage.read(key: _signingSeed);
    var agreement = await _storage.read(key: _agreementSeed);
    if (signing == null || agreement == null) {
      signing = b64(randomBytes(32));
      agreement = b64(randomBytes(32));
      await _storage.write(key: _signingSeed, value: signing);
      await _storage.write(key: _agreementSeed, value: agreement);
    }
    return DeviceKeys.fromSeeds(
      signingSeed: unb64(signing),
      agreementSeed: unb64(agreement),
    );
  }

  Future<String?> inviteCode() => _storage.read(key: _inviteCode);

  Future<void> setInviteCode(String? code) => code == null
      ? _storage.delete(key: _inviteCode)
      : _storage.write(key: _inviteCode, value: normalizeInviteCode(code));

  /// Erases every secret, including the device identity.
  Future<void> wipe() => _storage.deleteAll();
}
