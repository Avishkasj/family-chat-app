import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:nsd/nsd.dart' as nsd;

import '../shared/protocol.dart';

@immutable
class DiscoveredHub {
  const DiscoveredHub({
    required this.host,
    required this.port,
    required this.familyId,
    required this.familyName,
    required this.hubName,
  });

  final String host;
  final int port;
  final String familyId;
  final String familyName;
  final String hubName;

  @override
  bool operator ==(Object other) =>
      other is DiscoveredHub && other.familyId == familyId;

  @override
  int get hashCode => familyId.hashCode;
}

/// Finds family hubs on the local network using mDNS/DNS-SD and a UDP
/// broadcast fallback. No internet connection is involved.
class DiscoveryService {
  final NetworkInfo _networkInfo = NetworkInfo();

  /// Scans for [timeout], emitting the growing list of hubs found.
  Stream<List<DiscoveredHub>> scan({
    Duration timeout = const Duration(seconds: 6),
  }) {
    final found = <String, DiscoveredHub>{};
    late final StreamController<List<DiscoveredHub>> controller;
    nsd.Discovery? discovery;
    RawDatagramSocket? socket;
    Timer? probeTimer;
    Timer? endTimer;

    void add(DiscoveredHub hub) {
      if (controller.isClosed) return;
      found[hub.familyId] = hub;
      controller.add(found.values.toList());
    }

    Future<void> finish() async {
      probeTimer?.cancel();
      endTimer?.cancel();
      socket?.close();
      socket = null;
      final d = discovery;
      discovery = null;
      if (d != null) {
        try {
          await nsd.stopDiscovery(d);
        } catch (_) {}
      }
      if (!controller.isClosed) await controller.close();
    }

    controller = StreamController<List<DiscoveredHub>>(
      onListen: () async {
        endTimer = Timer(timeout, finish);
        controller.add(const []);

        try {
          discovery = await nsd.startDiscovery(
            kServiceType,
            ipLookupType: nsd.IpLookupType.v4,
          );
          discovery!.addServiceListener((service, status) {
            if (status != nsd.ServiceStatus.found) return;
            final hub = _fromService(service);
            if (hub != null) add(hub);
          });
        } catch (e) {
          debugPrint('mDNS discovery unavailable: $e');
        }

        try {
          final s = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
          socket = s;
          s.broadcastEnabled = true;
          s.listen((event) {
            if (event != RawSocketEvent.read) return;
            final datagram = s.receive();
            if (datagram == null) return;
            final hub = _fromDatagram(datagram);
            if (hub != null) add(hub);
          });
          final targets = await _broadcastTargets();
          void probe() {
            for (final target in targets) {
              try {
                s.send(utf8.encode(kDiscoveryProbe), target, kDiscoveryPort);
              } catch (_) {}
            }
          }

          probe();
          probeTimer = Timer.periodic(
            const Duration(milliseconds: 1500),
            (_) => probe(),
          );
        } catch (e) {
          debugPrint('UDP discovery unavailable: $e');
        }
      },
      onCancel: finish,
    );
    return controller.stream;
  }

  /// Looks for the hub of a specific family (e.g. after its IP changed).
  Future<DiscoveredHub?> find(
    String familyId, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    await for (final hubs in scan(timeout: timeout)) {
      for (final hub in hubs) {
        if (hub.familyId == familyId) return hub;
      }
    }
    return null;
  }

  Future<List<InternetAddress>> _broadcastTargets() async {
    final targets = <InternetAddress>[InternetAddress('255.255.255.255')];
    try {
      final broadcast = await _networkInfo.getWifiBroadcast();
      if (broadcast != null && broadcast.isNotEmpty) {
        targets.add(InternetAddress(broadcast.replaceAll('/', '')));
      }
    } catch (_) {}
    // Also probe each interface's /24 broadcast address.
    try {
      for (final iface in await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      )) {
        for (final address in iface.addresses) {
          if (address.isLoopback) continue;
          final parts = address.address.split('.');
          targets.add(InternetAddress('${parts[0]}.${parts[1]}.${parts[2]}.255'));
        }
      }
    } catch (_) {}
    return targets;
  }

  DiscoveredHub? _fromService(nsd.Service service) {
    final txt = service.txt ?? const {};
    String? text(String key) {
      final value = txt[key];
      return value == null ? null : utf8.decode(value, allowMalformed: true);
    }

    final familyId = text('fid');
    final host = service.addresses
            ?.where((a) => a.type == InternetAddressType.IPv4)
            .map((a) => a.address)
            .firstOrNull ??
        service.host;
    if (familyId == null || host == null || service.port == null) return null;
    return DiscoveredHub(
      host: host,
      port: service.port!,
      familyId: familyId,
      familyName: text('fn') ?? 'Family',
      hubName: service.name ?? '',
    );
  }

  DiscoveredHub? _fromDatagram(Datagram datagram) {
    try {
      final json = jsonDecode(utf8.decode(datagram.data));
      if (json is! Map<String, dynamic> || json['famnest'] != 1) return null;
      return DiscoveredHub(
        host: datagram.address.address,
        port: json['port'] as int? ?? kHubPort,
        familyId: json['familyId'] as String,
        familyName: json['familyName'] as String? ?? 'Family',
        hubName: json['hubName'] as String? ?? '',
      );
    } catch (_) {
      return null;
    }
  }
}
