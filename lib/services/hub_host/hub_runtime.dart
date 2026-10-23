import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:nsd/nsd.dart' as nsd;

import '../../shared/hub/hub_server.dart';
import '../../shared/hub/hub_store.dart';
import '../../shared/protocol.dart';

/// Creates a brand-new family hub in [directory].
({String familyId, String inviteCode}) createHubOnDisk({
  required String directory,
  required String familyName,
  required String hubName,
}) {
  final store = HubStore.open(directory);
  try {
    final code = store.isInitialized
        ? store.inviteCode
        : store.initialize(familyName: familyName, hubName: hubName);
    return (familyId: store.familyId, inviteCode: code);
  } finally {
    store.close();
  }
}

/// A running hub: database + WebSocket server + mDNS advertisement.
/// Used both in the main isolate and inside the Android foreground service.
class HubRuntime {
  HubRuntime(this.directory, {this.onStatus});

  final String directory;
  final void Function(HubStatus status)? onStatus;

  HubStore? _store;
  HubServer? _server;
  nsd.Registration? _registration;

  HubStatus get status => _server?.status ?? HubStatus.stopped;

  Future<void> start() async {
    if (_server != null) return;
    final store = HubStore.open(directory);
    if (!store.isInitialized) {
      store.close();
      throw StateError('No hub has been created on this device');
    }
    final server = HubServer(store, onStatus: onStatus, log: debugPrint);
    try {
      await server.start();
    } catch (_) {
      store.close();
      rethrow;
    }
    _store = store;
    _server = server;
    await _advertise();
  }

  Future<void> _advertise() async {
    final store = _store;
    if (store == null) return;
    try {
      final previous = _registration;
      _registration = null;
      if (previous != null) await nsd.unregister(previous);
      _registration = await nsd.register(
        nsd.Service(
          name: 'FamNest ${store.familyName}',
          type: kServiceType,
          port: kHubPort,
          txt: {
            'fid': utf8.encode(store.familyId),
            'fn': utf8.encode(store.familyName),
          },
        ),
      );
    } catch (e) {
      debugPrint('mDNS registration failed (UDP discovery still works): $e');
    }
  }

  Future<void> stop() async {
    final registration = _registration;
    _registration = null;
    if (registration != null) {
      try {
        await nsd.unregister(registration);
      } catch (_) {}
    }
    await _server?.stop();
    _server = null;
    _store?.close();
    _store = null;
    onStatus?.call(HubStatus.stopped);
  }

  Future<String> rotateInviteCode() => _require.rotateInviteCode();

  Future<void> removeMember(String deviceId) => _require.removeMember(deviceId);

  Future<void> renameFamily(String name) async {
    await _require.renameFamily(name);
    await _advertise();
  }

  HubServer get _require {
    final server = _server;
    if (server == null) throw StateError('Hub is not running');
    return server;
  }
}
