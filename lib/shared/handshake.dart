import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'crypto.dart';
import 'device_keys.dart';
import 'protocol.dart';
import 'secure_channel.dart';

/// Public information a hub announces before authentication.
class HubHello {
  const HubHello({
    required this.familyId,
    required this.familyName,
    required this.hubName,
    required this.nonce,
  });

  factory HubHello.fromJson(Map<String, dynamic> json) {
    if (json['t'] != 'hello') {
      throw const ProtocolException('Expected hello');
    }
    if (json['v'] != kProtocolVersion) {
      throw const HubAuthException(AuthFailure.version);
    }
    return HubHello(
      familyId: json['familyId'] as String,
      familyName: json['familyName'] as String? ?? '',
      hubName: json['hubName'] as String? ?? '',
      nonce: unb64(json['nonce'] as String),
    );
  }

  final String familyId;
  final String familyName;
  final String hubName;
  final List<int> nonce;
}

class HubAuthException implements Exception {
  const HubAuthException(this.reason);
  final String reason;

  @override
  String toString() => 'HubAuthException: $reason';
}

/// Thrown when the hub at an address belongs to another family.
class HubMismatchException implements Exception {
  const HubMismatchException();
}

class HubConnection {
  HubConnection(this.channel, this.hello);
  final SecureChannel channel;
  final HubHello hello;
}

/// Transcript both sides MAC/sign, binding the handshake to both nonces and
/// to the device's public keys.
List<int> clientTranscript(
  List<int> hubNonce,
  List<int> clientNonce,
  List<int> signingKey,
  List<int> agreementKey,
) => concatBytes([
  utf8.encode('famnest/v1/client'),
  hubNonce,
  clientNonce,
  signingKey,
  agreementKey,
]);

List<int> hubTranscript(List<int> hubNonce, List<int> clientNonce) =>
    concatBytes([utf8.encode('famnest/v1/hub'), hubNonce, clientNonce]);

Uri hubUri(String host, int port) {
  final h = host.contains(':') && !host.startsWith('[') ? '[$host]' : host;
  return Uri.parse('ws://$h:$port$kWebSocketPath');
}

Future<dynamic> _next(StreamIterator<dynamic> it) async {
  final hasNext = await it.moveNext().timeout(kHandshakeTimeout);
  if (!hasNext) throw const SocketException('Hub closed the connection');
  return it.current;
}

Map<String, dynamic> _decodeText(Object? raw) {
  if (raw is! String) throw const ProtocolException('Expected text frame');
  final value = jsonDecode(raw);
  if (value is! Map<String, dynamic>) {
    throw const ProtocolException('Expected object');
  }
  return value;
}

/// Reads a hub's hello without authenticating (used to identify a hub
/// typed in manually).
Future<HubHello> probeHub(String host, int port) async {
  final socket = await WebSocket.connect(
    hubUri(host, port).toString(),
  ).timeout(const Duration(seconds: 6));
  try {
    final it = StreamIterator<dynamic>(socket);
    return HubHello.fromJson(_decodeText(await _next(it)));
  } finally {
    unawaited(socket.close());
  }
}

/// Connects to a hub and performs mutual authentication:
/// - the device proves it knows the invite code (HMAC) and owns its identity
///   key (Ed25519 signature);
/// - the hub proves it knows the invite code too, so a rogue device on the
///   network can't impersonate the family hub.
Future<HubConnection> connectToHub({
  required String host,
  required int port,
  required String inviteCode,
  required DeviceKeys keys,
  String? expectedFamilyId,
}) async {
  final socket = await WebSocket.connect(
    hubUri(host, port).toString(),
  ).timeout(const Duration(seconds: 8));
  socket.pingInterval = kPingInterval;
  try {
    final it = StreamIterator<dynamic>(socket);
    final hello = HubHello.fromJson(_decodeText(await _next(it)));
    if (expectedFamilyId != null && hello.familyId != expectedFamilyId) {
      throw const HubMismatchException();
    }

    final authKey = await deriveAuthKey(inviteCode, hello.familyId);
    final clientNonce = randomBytes(32);
    final transcript = clientTranscript(
      hello.nonce,
      clientNonce,
      keys.signingPublicKey,
      keys.agreementPublicKey,
    );
    socket.add(
      jsonEncode({
        't': 'auth',
        'v': kProtocolVersion,
        'deviceId': keys.deviceId,
        'signKey': b64(keys.signingPublicKey),
        'dhKey': b64(keys.agreementPublicKey),
        'nonce': b64(clientNonce),
        'mac': b64(await hmacSha256(authKey, transcript)),
        'sig': b64(await keys.sign(transcript)),
      }),
    );

    final reply = _decodeText(await _next(it));
    if (reply['t'] == 'auth_fail') {
      throw HubAuthException(reply['reason'] as String? ?? 'unknown');
    }
    if (reply['t'] != 'auth_ok') {
      throw const ProtocolException('Unexpected handshake reply');
    }
    final expected = await hmacSha256(
      authKey,
      hubTranscript(hello.nonce, clientNonce),
    );
    if (!constantTimeEquals(expected, unb64(reply['mac'] as String))) {
      throw const HubAuthException(AuthFailure.identity);
    }

    final keysForSession = await deriveSessionKeys(
      authKey,
      hello.nonce,
      clientNonce,
    );
    final channel = SecureChannel(
      socket,
      it,
      sendKey: keysForSession.clientToHub,
      receiveKey: keysForSession.hubToClient,
    );
    return HubConnection(channel, hello);
  } catch (_) {
    unawaited(socket.close());
    rethrow;
  }
}
