import 'dart:io';

import 'package:famnest/data/local_database.dart';
import 'package:famnest/services/app_lock.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
// ignore: depend_on_referenced_packages
import 'package:local_auth_platform_interface/types/auth_messages.dart';
import 'package:path/path.dart' as p;

/// Stands in for Face ID: succeeds or fails on demand.
class FakeAuth extends LocalAuthentication {
  bool succeed = true;
  int prompts = 0;

  @override
  Future<bool> authenticate({
    required String localizedReason,
    Iterable<AuthMessages> authMessages = const [],
    bool biometricOnly = false,
    bool sensitiveTransaction = true,
    bool persistAcrossBackgrounding = false,
  }) async {
    prompts++;
    return succeed;
  }

  @override
  Future<bool> isDeviceSupported() async => true;

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async =>
      [BiometricType.face];
}

void main() {
  late Directory dir;
  late LocalDatabase db;
  late FakeAuth auth;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('famnest_lock');
    db = LocalDatabase.open(p.join(dir.path, 'db'));
    auth = FakeAuth();
  });

  tearDown(() async {
    db.close();
    await dir.delete(recursive: true);
  });

  test('enabling requires a successful check', () async {
    final lock = AppLock(db, auth: auth);
    auth.succeed = false;
    expect(await lock.enable('reason'), isFalse);
    expect(lock.enabled, isFalse);
    auth.succeed = true;
    expect(await lock.enable('reason'), isTrue);
    expect(lock.enabled, isTrue);
  });

  test('reports Face ID on iPhone', () async {
    final method = await AppLock(db, auth: auth).availableMethod();
    expect(
      method,
      Platform.isIOS || Platform.isMacOS ? LockMethod.faceId : LockMethod.face,
    );
  });

  test('locks at launch and after leaving the app', () async {
    final lock = AppLock(db, auth: auth);
    await lock.enable('reason');
    lock.timeout = LockTimeout.immediately;

    // A fresh launch starts locked.
    final launched = AppLock(db, auth: auth);
    expect(launched.locked, isTrue);
    auth.succeed = false;
    expect(await launched.unlock('reason'), isFalse);
    expect(launched.locked, isTrue);
    auth.succeed = true;
    expect(await launched.unlock('reason'), isTrue);
    expect(launched.locked, isFalse);

    // Control Center / app switcher: content hidden, no re-lock.
    launched.onLifecycle(AppLifecycleState.inactive);
    expect(launched.obscured, isTrue);
    launched.onLifecycle(AppLifecycleState.resumed);
    expect(launched.obscured, isFalse);
    expect(launched.locked, isFalse);

    // Actually leaving the app locks it.
    launched.onLifecycle(AppLifecycleState.inactive);
    launched.onLifecycle(AppLifecycleState.paused);
    launched.onLifecycle(AppLifecycleState.resumed);
    expect(launched.locked, isTrue);
  });

  test('short trips away within the timeout and pickers do not lock', () async {
    final lock = AppLock(db, auth: auth);
    await lock.enable('reason');
    await lock.unlock('reason');
    lock.timeout = LockTimeout.oneMinute;

    lock.onLifecycle(AppLifecycleState.paused);
    lock.onLifecycle(AppLifecycleState.resumed);
    expect(lock.locked, isFalse);

    lock.timeout = LockTimeout.immediately;
    await lock.whileExternal(() async {
      lock.onLifecycle(AppLifecycleState.paused); // photo picker open
      lock.onLifecycle(AppLifecycleState.resumed);
    });
    expect(lock.locked, isFalse);
  });

  test('turning the lock off unlocks the app', () async {
    final lock = AppLock(db, auth: auth);
    await lock.enable('reason');
    final launched = AppLock(db, auth: auth);
    expect(launched.locked, isTrue);
    launched.disable();
    expect(launched.locked, isFalse);
    expect(AppLock(db, auth: auth).locked, isFalse);
  });
}
