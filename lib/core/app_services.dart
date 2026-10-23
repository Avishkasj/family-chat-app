import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/local_database.dart';
import '../demo/demo_mode.dart';
import '../data/secure_vault.dart';
import '../services/app_lock.dart';
import '../services/chat_service.dart';
import '../services/discovery_service.dart';
import '../services/hub_host/hub_host.dart';
import '../services/hub_host/hub_runtime.dart';
import '../services/notification_service.dart';
import '../shared/device_keys.dart';

/// Everything the app needs, created once at startup. All data lives in the
/// app's private storage directory on this device.
class AppServices {
  AppServices._({
    required this.dataDirectory,
    required this.db,
    required this.vault,
    required this.keys,
    required this.notifications,
    required this.discovery,
    required this.chat,
    required this.hubHost,
    required this.appLock,
  });

  final String dataDirectory;
  final LocalDatabase db;
  final SecureVault vault;
  final DeviceKeys keys;
  final NotificationService notifications;
  final DiscoveryService discovery;
  final ChatService chat;
  final HubHost hubHost;
  final AppLock appLock;

  static const _storageChannel = MethodChannel('app.famnest/storage');

  static Future<AppServices> create() async {
    final support = await getApplicationSupportDirectory();
    final dataDirectory = p.join(support.path, 'famnest');
    await Directory(p.join(dataDirectory, 'files')).create(recursive: true);
    await Directory(p.join(dataDirectory, 'hub')).create(recursive: true);
    if (Platform.isIOS) {
      // Keep chats out of iCloud backups: data must stay on this device.
      try {
        await _storageChannel.invokeMethod('excludeFromBackup', dataDirectory);
      } catch (e) {
        debugPrint('Could not exclude data from backup: $e');
      }
    }

    final db = LocalDatabase.open(p.join(dataDirectory, 'famnest.db'));
    final vault = SecureVault();
    final keys = await vault.loadOrCreateKeys();
    db.upsertMember(
      keys.deviceId,
      agreementKey: keys.agreementPublicKey,
      notify: false,
    );

    final notifications = NotificationService();
    await notifications.initialize();
    final discovery = DiscoveryService();
    final chat = ChatService(
      db: db,
      vault: vault,
      keys: keys,
      discovery: discovery,
      notifications: notifications,
      filesDirectory: p.join(dataDirectory, 'files'),
    );
    final hubHost = HubHost.forPlatform(p.join(dataDirectory, 'hub'));
    final services = AppServices._(
      dataDirectory: dataDirectory,
      db: db,
      vault: vault,
      keys: keys,
      notifications: notifications,
      discovery: discovery,
      chat: chat,
      hubHost: hubHost,
      appLock: AppLock(db),
    );
    if (kDemoMode) {
      // App Store screenshots: sample family, no networking.
      await setUpDemo(dataDirectory: dataDirectory, db: db, chat: chat);
      return services;
    }
    services._handleNotificationAnswers();
    await services._resume();
    return services;
  }

  StreamSubscription<NotificationTap>? _answers;

  /// "On my way" etc. tapped directly on a family-call notification.
  void _handleNotificationAnswers() {
    void handle(NotificationTap tap) {
      final messageId = tap.messageId;
      final answer = tap.answer;
      if (messageId != null && answer != null) {
        chat.answerFromNotification(messageId, answer);
      }
    }

    final launch = notifications.launchTap;
    if (launch != null) handle(launch);
    _answers = notifications.taps.listen(handle);
  }

  Future<void> _resume() async {
    if (chat.isHubOwner) {
      await hubHost.attach();
      if (!hubHost.status.value.running && !db.getBool(Keys.hubPaused)) {
        try {
          await hubHost.start();
        } catch (e) {
          debugPrint('Could not start the family hub: $e');
        }
      }
      _followInviteCode();
    } else if (db.getBool(Keys.keepAlive)) {
      unawaited(hubHost.setKeepAlive(true).catchError((Object _) {}));
    }
    chat.start();
  }

  /// When this device hosts the hub, its own connection must follow invite
  /// code changes.
  void _followInviteCode() {
    var lastCode = hubHost.status.value.inviteCode;
    hubHost.status.addListener(() {
      final code = hubHost.status.value.inviteCode;
      if (code.isNotEmpty && code != lastCode) {
        lastCode = code;
        unawaited(chat.updateInviteCode(code));
      }
    });
  }

  /// Turns this device into the family hub and joins it.
  Future<void> createFamily({required String familyName}) async {
    final hub = createHubOnDisk(
      directory: hubHost.directory,
      familyName: familyName,
      hubName: Platform.localHostname,
    );
    await hubHost.start();
    _followInviteCode();
    await chat.configure(
      host: '127.0.0.1',
      port: hubHost.status.value.port,
      familyId: hub.familyId,
      familyName: familyName,
      inviteCode: hub.inviteCode,
      isHubOwner: true,
    );
  }

  /// Leaves the family and permanently erases all data on this device:
  /// messages, files, keys and (if hosted here) the family hub.
  Future<void> eraseEverything() async {
    await chat.stop();
    try {
      await hubHost.stop();
    } catch (_) {}
    await notifications.clearAll();
    db.destroy();
    await vault.wipe();
    final dir = Directory(dataDirectory);
    if (dir.existsSync()) await dir.delete(recursive: true);
  }

  void dispose() {
    unawaited(_answers?.cancel());
    unawaited(chat.stop());
  }
}
