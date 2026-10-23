import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:local_auth/local_auth.dart';

import '../data/local_database.dart';
import '../demo/demo_mode.dart';
import 'chat_service.dart';

/// Which unlock method the device offers, for labels and icons.
enum LockMethod { faceId, touchId, face, fingerprint, biometrics, passcode, none }

/// When the app locks again after leaving it.
enum LockTimeout {
  immediately(Duration.zero),
  oneMinute(Duration(minutes: 1)),
  fifteenMinutes(Duration(minutes: 15));

  const LockTimeout(this.duration);
  final Duration duration;
}

/// Optional app lock using Face ID / Touch ID / fingerprint, falling back to
/// the device passcode. Nothing leaves the device: the OS performs the check.
class AppLock extends ChangeNotifier {
  AppLock(this._db, {LocalAuthentication? auth})
    : _auth = auth ?? LocalAuthentication() {
    // Demo builds (App Store screenshots) show the setting but never lock.
    _locked = enabled && !kDemoMode;
  }

  final LocalDatabase _db;
  final LocalAuthentication _auth;

  bool _locked = false;
  bool _obscured = false;
  bool _authenticating = false;
  int _externalActivities = 0;
  DateTime? _leftAt;

  bool get enabled => _db.getBool(Keys.appLock);

  /// True while the lock screen must be shown.
  bool get locked => _locked;

  /// True while the app is in the app switcher: content is hidden.
  bool get obscured => _obscured;

  LockTimeout get timeout => LockTimeout.values.firstWhere(
    (t) => t.name == _db.getValue(Keys.appLockTimeout),
    orElse: () => LockTimeout.oneMinute,
  );

  set timeout(LockTimeout value) {
    _db.setValue(Keys.appLockTimeout, value.name);
    notifyListeners();
  }

  Future<LockMethod> availableMethod() async {
    try {
      if (!await _auth.isDeviceSupported()) return LockMethod.none;
      final types = await _auth.getAvailableBiometrics();
      final apple = Platform.isIOS || Platform.isMacOS;
      if (types.contains(BiometricType.face)) {
        return apple ? LockMethod.faceId : LockMethod.face;
      }
      if (types.contains(BiometricType.fingerprint)) {
        return apple ? LockMethod.touchId : LockMethod.fingerprint;
      }
      if (types.isNotEmpty) return LockMethod.biometrics;
      return LockMethod.passcode;
    } catch (_) {
      return LockMethod.none;
    }
  }

  /// Asks the OS to verify the user. Returns true on success.
  Future<bool> authenticate(String reason) async {
    if (_authenticating) return false;
    _authenticating = true;
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        persistAcrossBackgrounding: true,
      );
    } on LocalAuthException catch (e) {
      debugPrint('Authentication failed: ${e.code}');
      return false;
    } catch (e) {
      debugPrint('Authentication unavailable: $e');
      return false;
    } finally {
      _authenticating = false;
    }
  }

  /// Turns the lock on after the user proves they can unlock.
  Future<bool> enable(String reason) async {
    if (!await authenticate(reason)) return false;
    _db.setBool(Keys.appLock, true);
    notifyListeners();
    return true;
  }

  void disable() {
    _db.setBool(Keys.appLock, false);
    _locked = false;
    notifyListeners();
  }

  Future<bool> unlock(String reason) async {
    if (!_locked) return true;
    final ok = await authenticate(reason);
    if (ok) {
      _locked = false;
      notifyListeners();
    }
    return ok;
  }

  /// Runs [action] (photo picker, camera, file picker…) without locking the
  /// app when the OS briefly sends it to the background.
  Future<T> whileExternal<T>(Future<T> Function() action) async {
    _externalActivities++;
    try {
      return await action();
    } finally {
      _externalActivities--;
      _leftAt = null;
    }
  }

  void onLifecycle(AppLifecycleState state) {
    // The Face ID sheet itself makes the app inactive; ignore that.
    if (!enabled || _authenticating) return;
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        if (_externalActivities > 0) return;
        // Only actually leaving the app starts the lock timer; "inactive"
        // (app switcher, Control Center) just hides the content.
        if (state != AppLifecycleState.inactive) _leftAt ??= DateTime.now();
        if (!_obscured) {
          _obscured = true;
          notifyListeners();
        }
      case AppLifecycleState.resumed:
        final leftAt = _leftAt;
        _leftAt = null;
        if (leftAt != null &&
            DateTime.now().difference(leftAt) >= timeout.duration) {
          _locked = true;
        }
        _obscured = false;
        notifyListeners();
      case AppLifecycleState.detached:
        break;
    }
  }
}
