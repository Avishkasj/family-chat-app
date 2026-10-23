import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../../shared/crypto.dart';
import '../../shared/handshake.dart';
import '../../shared/hub/hub_server.dart';
import 'hub_runtime.dart';

/// Controls the family hub hosted on this device.
abstract class HubHost {
  factory HubHost.forPlatform(String directory) => Platform.isAndroid
      ? AndroidServiceHubHost(directory)
      : InProcessHubHost(directory);

  String get directory;

  ValueListenable<HubStatus> get status;

  /// Re-attaches to a hub that is already running (e.g. the Android service
  /// kept it alive while the app was closed).
  Future<void> attach();

  Future<void> start();

  Future<void> stop();

  /// Checks a started hub still accepts connections (e.g. after the app was
  /// suspended) and restarts it if not.
  Future<void> ensureRunning();

  Future<String> rotateInviteCode();

  Future<void> removeMember(String deviceId);

  Future<void> renameFamily(String name);

  /// On Android, keeps a member device's connection alive in the background
  /// with a low-priority notification. No-op on other platforms.
  Future<void> setKeepAlive(bool enabled);
}

/// Runs the hub inside the app process. On iOS the hub only works while the
/// app is open, so an Android phone/tablet or the headless hub is
/// recommended as the always-on family hub.
class InProcessHubHost implements HubHost {
  InProcessHubHost(this.directory);

  @override
  final String directory;
  final ValueNotifier<HubStatus> _status = ValueNotifier(HubStatus.stopped);
  HubRuntime? _runtime;

  @override
  ValueListenable<HubStatus> get status => _status;

  @override
  Future<void> attach() async {}

  @override
  Future<void> start() async {
    if (_runtime != null) return;
    final runtime = HubRuntime(directory, onStatus: (s) => _status.value = s);
    await runtime.start();
    _runtime = runtime;
  }

  @override
  Future<void> stop() async {
    await _runtime?.stop();
    _runtime = null;
    _status.value = HubStatus.stopped;
  }

  @override
  Future<void> ensureRunning() async {
    if (_runtime == null) return;
    try {
      await probeHub('127.0.0.1', _status.value.port);
    } catch (_) {
      await stop();
      await start();
    }
  }

  @override
  Future<String> rotateInviteCode() => _require.rotateInviteCode();

  @override
  Future<void> removeMember(String deviceId) => _require.removeMember(deviceId);

  @override
  Future<void> renameFamily(String name) => _require.renameFamily(name);

  @override
  Future<void> setKeepAlive(bool enabled) async {}

  HubRuntime get _require =>
      _runtime ?? (throw StateError('Hub is not running'));
}

// ---------------------------------------------------------------------------
// Android: the hub runs inside a foreground service isolate so it keeps
// serving the family when the app is in the background or swiped away, and
// restarts after a reboot.
// ---------------------------------------------------------------------------

const _modeKey = 'famnest_mode';
const _dirKey = 'famnest_hub_dir';
const _modeHub = 'hub';
const _modeKeepAlive = 'keepalive';

@pragma('vm:entry-point')
void famnestServiceCallback() {
  FlutterForegroundTask.setTaskHandler(_FamNestTaskHandler());
}

class _FamNestTaskHandler extends TaskHandler {
  HubRuntime? _runtime;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    final mode = await FlutterForegroundTask.getData<String>(key: _modeKey);
    if (mode != _modeHub) return;
    final directory = await FlutterForegroundTask.getData<String>(key: _dirKey);
    if (directory == null) return;
    final runtime = HubRuntime(directory, onStatus: _publish);
    try {
      await runtime.start();
      _runtime = runtime;
    } catch (e) {
      FlutterForegroundTask.sendDataToMain({'type': 'error', 'error': '$e'});
    }
  }

  void _publish(HubStatus status) {
    FlutterForegroundTask.sendDataToMain({
      'type': 'status',
      'status': status.toJson(),
    });
    if (status.running) {
      final online = status.online.length;
      FlutterForegroundTask.updateService(
        notificationTitle: 'Family hub is running',
        notificationText:
            '${status.familyName} · $online of ${status.memberCount} online',
      );
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onReceiveData(Object data) async {
    if (data is! Map) return;
    final requestId = data['id'];
    Object? result;
    String? error;
    try {
      final runtime = _runtime;
      switch (data['cmd']) {
        case 'status':
          result = (runtime?.status ?? HubStatus.stopped).toJson();
        case 'rotate':
          result = await runtime!.rotateInviteCode();
        case 'remove':
          await runtime!.removeMember(data['deviceId'] as String);
        case 'rename':
          await runtime!.renameFamily(data['name'] as String);
      }
    } catch (e) {
      error = '$e';
    }
    FlutterForegroundTask.sendDataToMain({
      'type': 'reply',
      'id': requestId,
      'result': result,
      'error': error,
    });
  }

  @override
  void onNotificationPressed() => FlutterForegroundTask.launchApp('/');

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    await _runtime?.stop();
    _runtime = null;
  }
}

class AndroidServiceHubHost implements HubHost {
  AndroidServiceHubHost(this.directory) {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'famnest_service',
        channelName: 'Family hub',
        channelDescription: 'Shown while FamNest keeps your family connected.',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
    FlutterForegroundTask.addTaskDataCallback(_onData);
  }

  @override
  final String directory;
  final ValueNotifier<HubStatus> _status = ValueNotifier(HubStatus.stopped);
  final Map<String, Completer<Object?>> _pending = {};

  @override
  ValueListenable<HubStatus> get status => _status;

  void _onData(Object data) {
    if (data is! Map) return;
    switch (data['type']) {
      case 'status':
        _status.value = HubStatus.fromJson(
          Map<String, dynamic>.from(data['status'] as Map),
        );
      case 'reply':
        final completer = _pending.remove(data['id']);
        final error = data['error'];
        if (error != null) {
          completer?.completeError(StateError(error as String));
        } else {
          completer?.complete(data['result']);
        }
      case 'error':
        debugPrint('Hub service error: ${data['error']}');
    }
  }

  Future<Object?> _request(Map<String, Object> command) {
    final id = randomId(8);
    final completer = Completer<Object?>();
    _pending[id] = completer;
    FlutterForegroundTask.sendDataToTask({...command, 'id': id});
    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        _pending.remove(id);
        throw TimeoutException('Hub service did not respond');
      },
    );
  }

  Future<bool> _isHubMode() async =>
      await FlutterForegroundTask.isRunningService &&
      await FlutterForegroundTask.getData<String>(key: _modeKey) == _modeHub;

  @override
  Future<void> attach() async {
    if (!await _isHubMode()) return;
    try {
      final json = await _request({'cmd': 'status'});
      if (json is Map) {
        _status.value = HubStatus.fromJson(Map<String, dynamic>.from(json));
      }
    } catch (e) {
      debugPrint('Could not reach hub service: $e');
    }
  }

  Future<void> _startService(String mode) async {
    if (await FlutterForegroundTask.checkNotificationPermission() !=
        NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
    await FlutterForegroundTask.saveData(key: _modeKey, value: mode);
    await FlutterForegroundTask.saveData(key: _dirKey, value: directory);
    final result = await FlutterForegroundTask.startService(
      serviceId: 4782,
      serviceTypes: [ForegroundServiceTypes.remoteMessaging],
      notificationTitle: mode == _modeHub
          ? 'Family hub is running'
          : 'FamNest is connected',
      notificationText: mode == _modeHub
          ? 'Keeping your family chat available on Wi-Fi'
          : 'Receiving family messages in the background',
      notificationIcon: const NotificationIcon(
        metaDataName: 'app.famnest.chat.NOTIFICATION_ICON',
        backgroundColor: Color(0xFF0F7B6C),
      ),
      notificationInitialRoute: '/',
      callback: famnestServiceCallback,
    );
    if (result is ServiceRequestFailure) throw result.error;
  }

  @override
  Future<void> start() async {
    if (await _isHubMode()) return attach();
    await _startService(_modeHub);
    // Wait for the service isolate to report that the hub is up.
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (!_status.value.running && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await attach();
    }
    if (!_status.value.running) {
      throw StateError('The family hub did not start. Is port in use?');
    }
  }

  @override
  Future<void> stop() async {
    await FlutterForegroundTask.saveData(key: _modeKey, value: '');
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
    _status.value = HubStatus.stopped;
  }

  @override
  Future<void> ensureRunning() async {
    if (await _isHubMode()) await attach();
  }

  @override
  Future<String> rotateInviteCode() async =>
      await _request({'cmd': 'rotate'}) as String;

  @override
  Future<void> removeMember(String deviceId) =>
      _request({'cmd': 'remove', 'deviceId': deviceId});

  @override
  Future<void> renameFamily(String name) =>
      _request({'cmd': 'rename', 'name': name});

  @override
  Future<void> setKeepAlive(bool enabled) async {
    if (await _isHubMode()) return; // The hub service already keeps us alive.
    final running = await FlutterForegroundTask.isRunningService;
    if (enabled && !running) {
      await _startService(_modeKeepAlive);
    } else if (!enabled && running) {
      await FlutterForegroundTask.stopService();
    }
  }
}
