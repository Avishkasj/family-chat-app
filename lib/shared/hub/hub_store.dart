import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../crypto.dart';
import '../protocol.dart';

class HubMember {
  HubMember({
    required this.id,
    required this.signKey,
    required this.dhKey,
    required this.profile,
    required this.profileVersion,
    required this.joinedAt,
    required this.lastSeen,
    required this.removed,
  });

  factory HubMember._fromRow(Row row) => HubMember(
    id: row['device_id'] as String,
    signKey: row['sign_key'] as String,
    dhKey: row['dh_key'] as String,
    profile: row['profile'] as String?,
    profileVersion: row['profile_ver'] as int,
    joinedAt: row['joined_at'] as int,
    lastSeen: row['last_seen'] as int,
    removed: (row['removed'] as int) == 1,
  );

  final String id;
  final String signKey;
  final String dhKey;
  final String? profile;
  final int profileVersion;
  final int joinedAt;
  final int lastSeen;
  final bool removed;

  Map<String, dynamic> toJson() => {
    'id': id,
    'signKey': signKey,
    'dhKey': dhKey,
    'profile': profile,
    'profileVer': profileVersion,
    'joinedAt': joinedAt,
    'lastSeen': lastSeen,
    'removed': removed,
  };
}

class HubConversation {
  HubConversation({
    required this.id,
    required this.members,
    required this.meta,
    required this.createdBy,
    required this.updatedAt,
  });

  factory HubConversation._fromRow(Row row) => HubConversation(
    id: row['id'] as String,
    members: (jsonDecode(row['members'] as String) as List).cast<String>(),
    meta: row['meta'] as String?,
    createdBy: row['created_by'] as String,
    updatedAt: row['updated_at'] as int,
  );

  final String id;
  final List<String> members;

  /// Encrypted group metadata (name), opaque to the hub.
  final String? meta;
  final String createdBy;
  final int updatedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': 'group',
    'members': members,
    'meta': meta,
    'createdBy': createdBy,
    'updatedAt': updatedAt,
  };
}

class HubMessage {
  HubMessage({
    required this.id,
    required this.seq,
    required this.conversationId,
    required this.sender,
    required this.timestamp,
    required this.body,
    required this.deleted,
  });

  factory HubMessage._fromRow(Row row) => HubMessage(
    id: row['id'] as String,
    seq: row['seq'] as int,
    conversationId: row['conv'] as String,
    sender: row['sender'] as String,
    timestamp: row['ts'] as int,
    body: row['body'] as String?,
    deleted: (row['deleted'] as int) == 1,
  );

  final String id;
  final int seq;
  final String conversationId;
  final String sender;
  final int timestamp;

  /// End-to-end encrypted payload, opaque to the hub.
  final String? body;
  final bool deleted;

  Map<String, dynamic> toJson() => {
    'id': id,
    'seq': seq,
    'conv': conversationId,
    'from': sender,
    'ts': timestamp,
    'body': body,
    'deleted': deleted,
  };
}

/// Persistent state of a family hub. The hub only ever stores ciphertext for
/// message bodies, profiles, group names and files.
class HubStore {
  HubStore._(this.directory, this._db);

  static HubStore open(String directory) {
    Directory(p.join(directory, 'files')).createSync(recursive: true);
    final db = sqlite3.open(p.join(directory, 'hub.db'));
    db
      ..execute('PRAGMA journal_mode = WAL')
      ..execute('PRAGMA foreign_keys = ON')
      ..execute('''
        CREATE TABLE IF NOT EXISTS config (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        );
        CREATE TABLE IF NOT EXISTS members (
          device_id TEXT PRIMARY KEY,
          sign_key TEXT NOT NULL,
          dh_key TEXT NOT NULL,
          profile TEXT,
          profile_ver INTEGER NOT NULL DEFAULT 0,
          joined_at INTEGER NOT NULL,
          last_seen INTEGER NOT NULL,
          removed INTEGER NOT NULL DEFAULT 0
        );
        CREATE TABLE IF NOT EXISTS conversations (
          id TEXT PRIMARY KEY,
          members TEXT NOT NULL,
          meta TEXT,
          created_by TEXT NOT NULL,
          updated_at INTEGER NOT NULL
        );
        CREATE TABLE IF NOT EXISTS messages (
          id TEXT PRIMARY KEY,
          seq INTEGER NOT NULL UNIQUE,
          conv TEXT NOT NULL,
          sender TEXT NOT NULL,
          ts INTEGER NOT NULL,
          body TEXT,
          deleted INTEGER NOT NULL DEFAULT 0
        );
        CREATE INDEX IF NOT EXISTS messages_conv_seq ON messages(conv, seq);
        CREATE TABLE IF NOT EXISTS files (
          id TEXT PRIMARY KEY,
          size INTEGER NOT NULL,
          owner TEXT NOT NULL,
          created_at INTEGER NOT NULL
        );
      ''');
    return HubStore._(directory, db);
  }

  final String directory;
  final Database _db;

  String get filesDirectory => p.join(directory, 'files');

  void close() => _db.close();

  // -- config ---------------------------------------------------------------

  String? _config(String key) {
    final rows = _db.select('SELECT value FROM config WHERE key = ?', [key]);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  void _setConfig(String key, String value) => _db.execute(
    'INSERT INTO config (key, value) VALUES (?, ?) '
    'ON CONFLICT(key) DO UPDATE SET value = excluded.value',
    [key, value],
  );

  bool get isInitialized => _config('familyId') != null;

  /// Creates a new family. Returns the invite code.
  String initialize({required String familyName, required String hubName}) {
    if (isInitialized) throw StateError('Hub already initialized');
    final code = generateInviteCode();
    _db.execute('BEGIN');
    try {
      _setConfig('familyId', randomId());
      _setConfig('familyName', familyName);
      _setConfig('hubName', hubName);
      _setConfig('inviteCode', code);
      _setConfig('contentKey', b64(randomBytes(32)));
      _setConfig('seq', '0');
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
    return code;
  }

  String get familyId => _config('familyId')!;
  String get familyName => _config('familyName')!;
  String get hubName => _config('hubName') ?? 'FamNest hub';
  String get inviteCode => _config('inviteCode')!;
  String get contentKey => _config('contentKey')!;
  int get latestSeq => int.parse(_config('seq') ?? '0');

  set familyName(String value) => _setConfig('familyName', value);

  String rotateInviteCode() {
    final code = generateInviteCode();
    _setConfig('inviteCode', code);
    return code;
  }

  int _nextSeq() {
    final next = latestSeq + 1;
    _setConfig('seq', '$next');
    return next;
  }

  T _transaction<T>(T Function() body) {
    _db.execute('BEGIN IMMEDIATE');
    try {
      final result = body();
      _db.execute('COMMIT');
      return result;
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  // -- members --------------------------------------------------------------

  HubMember? member(String id) {
    final rows = _db.select('SELECT * FROM members WHERE device_id = ?', [id]);
    return rows.isEmpty ? null : HubMember._fromRow(rows.first);
  }

  List<HubMember> members() => _db
      .select('SELECT * FROM members ORDER BY joined_at')
      .map(HubMember._fromRow)
      .toList();

  Set<String> activeMemberIds() => _db
      .select('SELECT device_id FROM members WHERE removed = 0')
      .map((r) => r['device_id'] as String)
      .toSet();

  HubMember registerMember({
    required String id,
    required String signKey,
    required String dhKey,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    _db.execute(
      'INSERT INTO members (device_id, sign_key, dh_key, joined_at, last_seen) '
      'VALUES (?, ?, ?, ?, ?) '
      'ON CONFLICT(device_id) DO UPDATE SET dh_key = excluded.dh_key, '
      'last_seen = excluded.last_seen',
      [id, signKey, dhKey, now, now],
    );
    return member(id)!;
  }

  HubMember updateProfile(String id, String profile) {
    _db.execute(
      'UPDATE members SET profile = ?, profile_ver = profile_ver + 1 '
      'WHERE device_id = ?',
      [profile, id],
    );
    return member(id)!;
  }

  void touchMember(String id) => _db.execute(
    'UPDATE members SET last_seen = ? WHERE device_id = ?',
    [DateTime.now().millisecondsSinceEpoch, id],
  );

  void setRemoved(String id, {required bool removed}) => _db.execute(
    'UPDATE members SET removed = ? WHERE device_id = ?',
    [removed ? 1 : 0, id],
  );

  // -- conversations ---------------------------------------------------------

  HubConversation? conversation(String id) {
    final rows = _db.select('SELECT * FROM conversations WHERE id = ?', [id]);
    return rows.isEmpty ? null : HubConversation._fromRow(rows.first);
  }

  List<HubConversation> conversationsFor(String deviceId) => _db
      .select(
        'SELECT c.* FROM conversations c, json_each(c.members) m '
        'WHERE m.value = ?',
        [deviceId],
      )
      .map(HubConversation._fromRow)
      .toList();

  HubConversation saveConversation({
    required String id,
    required List<String> members,
    required String? meta,
    required String createdBy,
  }) {
    _db.execute(
      'INSERT INTO conversations (id, members, meta, created_by, updated_at) '
      'VALUES (?, ?, ?, ?, ?) '
      'ON CONFLICT(id) DO UPDATE SET members = excluded.members, '
      'meta = excluded.meta, updated_at = excluded.updated_at',
      [
        id,
        jsonEncode(members),
        meta,
        createdBy,
        DateTime.now().millisecondsSinceEpoch,
      ],
    );
    return conversation(id)!;
  }

  /// Device ids that may read [conversationId], or null if it doesn't exist.
  Set<String>? recipientsOf(String conversationId) {
    final active = activeMemberIds();
    if (conversationId == kFamilyConversationId) return active;
    final direct = directConversationMembers(conversationId);
    if (direct != null) {
      return direct.every(active.contains) ? direct.toSet() : null;
    }
    final conv = conversation(conversationId);
    if (conv == null) return null;
    return conv.members.where(active.contains).toSet();
  }

  // -- messages --------------------------------------------------------------

  HubMessage? message(String id) {
    final rows = _db.select('SELECT * FROM messages WHERE id = ?', [id]);
    return rows.isEmpty ? null : HubMessage._fromRow(rows.first);
  }

  /// Stores a message. Idempotent on [id] so clients can safely retry.
  HubMessage insertMessage({
    required String id,
    required String conversationId,
    required String sender,
    required String body,
  }) {
    final existing = message(id);
    if (existing != null) return existing;
    return _transaction(() {
      final seq = _nextSeq();
      _db.execute(
        'INSERT INTO messages (id, seq, conv, sender, ts, body) '
        'VALUES (?, ?, ?, ?, ?, ?)',
        [
          id,
          seq,
          conversationId,
          sender,
          DateTime.now().millisecondsSinceEpoch,
          body,
        ],
      );
      return message(id)!;
    });
  }

  /// Deletes a message's content for everyone. The row gets a new sequence
  /// number so devices that sync later also learn about the deletion.
  HubMessage? deleteMessage(String id, String requester) {
    final existing = message(id);
    if (existing == null || existing.sender != requester) return null;
    if (existing.deleted) return existing;
    return _transaction(() {
      _db.execute(
        'UPDATE messages SET body = NULL, deleted = 1, seq = ? WHERE id = ?',
        [_nextSeq(), id],
      );
      return message(id)!;
    });
  }

  /// Messages visible to [deviceId] with a sequence number above [since].
  List<HubMessage> messagesSince(String deviceId, int since, {int limit = 200}) {
    final groups = conversationsFor(deviceId).map((c) => c.id).toList();
    final placeholders = List.filled(groups.length, '?').join(',');
    final groupClause = groups.isEmpty ? '' : 'OR conv IN ($placeholders)';
    return _db
        .select(
          'SELECT * FROM messages WHERE seq > ? AND ('
          "conv = ? OR (conv LIKE 'dm:%' AND instr(conv, ?) > 0) $groupClause"
          ') ORDER BY seq LIMIT ?',
          [since, kFamilyConversationId, deviceId, ...groups, limit],
        )
        .map(HubMessage._fromRow)
        .toList();
  }

  // -- files -----------------------------------------------------------------

  String filePath(String fileId) => p.join(filesDirectory, '$fileId.bin');

  void insertFile(String id, int size, String owner) => _db.execute(
    'INSERT OR REPLACE INTO files (id, size, owner, created_at) '
    'VALUES (?, ?, ?, ?)',
    [id, size, owner, DateTime.now().millisecondsSinceEpoch],
  );

  int? fileSize(String id) {
    final rows = _db.select('SELECT size FROM files WHERE id = ?', [id]);
    return rows.isEmpty ? null : rows.first['size'] as int;
  }
}
