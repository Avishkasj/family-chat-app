import 'dart:convert';
import 'dart:io';

import '../protocol.dart';

/// Answers UDP broadcast probes so devices on the same Wi-Fi can find the hub
/// without typing an IP address. Complements mDNS, which some routers block.
class DiscoveryResponder {
  DiscoveryResponder({required this.describe});

  /// Returns the JSON payload sent back to a probing device.
  final Map<String, dynamic> Function() describe;

  RawDatagramSocket? _socket;

  Future<void> start() async {
    final socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      kDiscoveryPort,
      reuseAddress: true,
    );
    _socket = socket;
    socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      final datagram = socket.receive();
      if (datagram == null) return;
      if (utf8.decode(datagram.data, allowMalformed: true) != kDiscoveryProbe) {
        return;
      }
      final reply = utf8.encode(jsonEncode({'famnest': 1, ...describe()}));
      socket.send(reply, datagram.address, datagram.port);
    });
  }

  void stop() {
    _socket?.close();
    _socket = null;
  }
}
