import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'crypto.dart';
import 'protocol.dart';

class ProtocolException implements Exception {
  const ProtocolException(this.message);
  final String message;

  @override
  String toString() => 'ProtocolException: $message';
}

sealed class ChannelFrame {}

class JsonFrame extends ChannelFrame {
  JsonFrame(this.data);
  final Map<String, dynamic> data;

  String get type => data['t'] as String? ?? '';
}

class ChunkFrame extends ChannelFrame {
  ChunkFrame(this.fileId, this.index, this.data);
  final String fileId;
  final int index;
  final Uint8List data;
}

const int _kindJson = 1;
const int _kindChunk = 2;

/// An authenticated, encrypted, replay-protected channel on top of a
/// WebSocket. Each direction has its own AES-256-GCM key; frame nonces are an
/// implicit counter, so dropped, reordered or replayed frames fail to decrypt.
class SecureChannel {
  SecureChannel(
    this.socket,
    this._incoming, {
    required this._sendKey,
    required this._receiveKey,
  });

  final WebSocket socket;
  final StreamIterator<dynamic> _incoming;
  final SecretKey _sendKey;
  final SecretKey _receiveKey;

  int _sendCounter = 0;
  int _receiveCounter = 0;
  Future<void> _sendTail = Future.value();
  bool _closed = false;

  bool get isClosed => _closed || socket.readyState != WebSocket.open;

  /// Decrypted frames, in order. Completes when the socket closes and throws
  /// on any authentication failure.
  Stream<ChannelFrame> frames() async* {
    while (await _incoming.moveNext()) {
      final raw = _incoming.current;
      if (raw is! List<int>) {
        throw const ProtocolException('Unexpected plaintext frame');
      }
      final plain = await openWithCounter(
        raw,
        _receiveKey,
        _receiveCounter++,
      );
      yield _decode(plain);
    }
  }

  Future<void> sendJson(Map<String, dynamic> data) {
    final json = utf8.encode(jsonEncode(data));
    final plain = Uint8List(json.length + 1)
      ..[0] = _kindJson
      ..setRange(1, json.length + 1, json);
    return _send(plain);
  }

  Future<void> sendChunk(String fileId, int index, List<int> data) {
    final id = ascii.encode(fileId);
    if (id.length > 255) throw ArgumentError('fileId too long');
    final plain = Uint8List(1 + 1 + id.length + 4 + data.length);
    final view = ByteData.sublistView(plain);
    plain[0] = _kindChunk;
    plain[1] = id.length;
    plain.setRange(2, 2 + id.length, id);
    view.setUint32(2 + id.length, index);
    plain.setRange(6 + id.length, plain.length, data);
    return _send(plain);
  }

  Future<void> _send(Uint8List plain) {
    final result = _sendTail.then((_) async {
      if (isClosed) throw const SocketException('Channel closed');
      final sealed = await sealWithCounter(plain, _sendKey, _sendCounter++);
      socket.add(sealed);
    });
    _sendTail = result.catchError((Object _) {});
    return result;
  }

  ChannelFrame _decode(Uint8List plain) {
    if (plain.isEmpty) throw const ProtocolException('Empty frame');
    switch (plain[0]) {
      case _kindJson:
        if (plain.length > kMaxJsonFrameBytes) {
          throw const ProtocolException('Frame too large');
        }
        final decoded = jsonDecode(utf8.decode(plain.sublist(1)));
        if (decoded is! Map<String, dynamic>) {
          throw const ProtocolException('Frame is not an object');
        }
        return JsonFrame(decoded);
      case _kindChunk:
        final idLength = plain[1];
        final fileId = ascii.decode(plain.sublist(2, 2 + idLength));
        final index = ByteData.sublistView(plain).getUint32(2 + idLength);
        return ChunkFrame(
          fileId,
          index,
          Uint8List.sublistView(plain, 6 + idLength),
        );
      default:
        throw const ProtocolException('Unknown frame kind');
    }
  }

  Future<void> close([int code = WebSocketStatus.normalClosure]) async {
    if (_closed) return;
    _closed = true;
    await socket.close(code).timeout(
      const Duration(seconds: 3),
      onTimeout: () => null,
    );
  }
}
