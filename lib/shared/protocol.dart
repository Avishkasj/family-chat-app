// Wire protocol constants shared by the app and the hub.
//
// This library (and everything under lib/shared) must stay free of Flutter
// imports so the hub can also run as a plain Dart program (bin/famnest_hub.dart).

const int kProtocolVersion = 1;

/// TCP port the hub's WebSocket server listens on.
const int kHubPort = 47820;

/// UDP port the hub answers discovery probes on.
const int kDiscoveryPort = 47821;

/// DNS-SD service type advertised over mDNS / Bonjour.
const String kServiceType = '_famnest._tcp';

const String kDiscoveryProbe = 'FAMNEST_DISCOVER_V1';
const String kWebSocketPath = '/ws';

/// Id of the conversation every family member belongs to.
const String kFamilyConversationId = 'family';

/// Plaintext bytes per file chunk. Each encrypted chunk adds a 16-byte tag.
const int kFileChunkSize = 256 * 1024;
const int kAeadTagLength = 16;
const int kEncryptedChunkSize = kFileChunkSize + kAeadTagLength;

/// Largest attachment accepted by the hub.
const int kMaxFileSize = 200 * 1024 * 1024;

/// Number of file chunks allowed in flight before waiting for an ack.
const int kFileWindow = 8;

/// Hard cap on a single JSON frame (profiles carry a small avatar).
const int kMaxJsonFrameBytes = 2 * 1024 * 1024;

/// Upper bound on the encrypted profile blob a member can publish.
const int kMaxProfileBytes = 256 * 1024;

/// Upper bound on an encrypted message body.
const int kMaxBodyBytes = 256 * 1024;

const Duration kHandshakeTimeout = Duration(seconds: 15);
const Duration kPingInterval = Duration(seconds: 20);

/// Message types ("t" field) used after the secure channel is established.
abstract final class Msg {
  // hub -> client
  static const welcome = 'welcome';
  static const message = 'msg';
  static const ack = 'ack';
  static const batch = 'batch';
  static const member = 'member';
  static const presence = 'presence';
  static const conversation = 'conv';
  static const typing = 'typing';
  static const fileInfo = 'file_info';
  static const fileOk = 'file_ok';
  static const fileError = 'file_err';
  static const fileAck = 'file_ack';
  static const error = 'error';

  // client -> hub
  static const profile = 'profile';
  static const send = 'send';
  static const delete = 'delete';
  static const sync = 'sync';
  static const conversationUpsert = 'conv_upsert';
  static const filePut = 'file_put';
  static const fileGet = 'file_get';
}

/// Reasons a hub can refuse a connection during the handshake.
abstract final class AuthFailure {
  static const badCode = 'bad_code';
  static const removed = 'removed';
  static const version = 'version';
  static const identity = 'identity';
}

/// Returns the canonical id of the direct conversation between two devices.
String directConversationId(String a, String b) {
  final ids = [a, b]..sort();
  return 'dm:${ids[0]}:${ids[1]}';
}

/// Returns the two device ids of a direct conversation, or null.
List<String>? directConversationMembers(String conversationId) {
  if (!conversationId.startsWith('dm:')) return null;
  final parts = conversationId.split(':');
  if (parts.length != 3 || parts[1] == parts[2]) return null;
  return [parts[1], parts[2]];
}

/// Number of chunks used to transfer a file of [size] plaintext bytes.
int chunkCountFor(int size) =>
    size <= 0 ? 1 : (size + kFileChunkSize - 1) ~/ kFileChunkSize;

/// Size on disk of a file of [size] plaintext bytes once encrypted.
int encryptedSizeFor(int size) => size + chunkCountFor(size) * kAeadTagLength;
