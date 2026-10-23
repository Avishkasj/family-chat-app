import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart';

import '../shared/protocol.dart';
import 'models.dart';

enum DbTable { kv, members, conversations, messages }

class DbChange {
  const DbChange(this.table, [this.conversationId]);
  final DbTable table;
  final String? conversationId;
}

/// On-device storage for everything this device knows: settings, family
/// members, conversations and message history. Nothing leaves the device
/// except through the encrypted hub connection.
class LocalDatabase {
  LocalDatabase._(this.path, this._db);

  static LocalDatabase open(String path) {
    final db = sqlite3.open(path);
    db
      ..execute('PRAGMA journal_mode = WAL')
      ..execute('''
        CREATE TABLE IF NOT EXISTS kv (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        );
        CREATE TABLE IF NOT EXISTS members (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL DEFAULT '',
          avatar BLOB,
          dh_key BLOB,
          last_seen INTEGER,
          joined_at INTEGER,
          removed INTEGER NOT NULL DEFAULT 0
        );
        CREATE TABLE IF NOT EXISTS conversations (
          id TEXT PRIMARY KEY,
          type TEXT NOT NULL,
          name TEXT NOT NULL DEFAULT '',
          members TEXT NOT NULL DEFAULT '[]',
          created_by TEXT,
          last_ts INTEGER,
          last_preview TEXT,
          last_sender TEXT,
          unread INTEGER NOT NULL DEFAULT 0,
          muted INTEGER NOT NULL DEFAULT 0
        );
        CREATE TABLE IF NOT EXISTS messages (
          id TEXT PRIMARY KEY,
          conv TEXT NOT NULL,
          sender TEXT NOT NULL,
          ts INTEGER NOT NULL,
          seq INTEGER,
          status INTEGER NOT NULL,
          text TEXT,
          attachment TEXT,
          deleted INTEGER NOT NULL DEFAULT 0,
          local_path TEXT,
          transfer INTEGER NOT NULL DEFAULT 0
        );
        CREATE INDEX IF NOT EXISTS messages_conv_ts ON messages(conv, ts);
      ''');
    _migrate(db);
    return LocalDatabase._(path, db);
  }

  static const _schemaVersion = 2;

  static void _migrate(Database db) {
    final version = db.userVersion;
    if (version < 2) {
      // v2: polls, family calls and their responses.
      final columns = db
          .select('PRAGMA table_info(messages)')
          .map((r) => r['name'] as String)
          .toSet();
      if (!columns.contains('kind')) {
        db.execute(
          "ALTER TABLE messages ADD COLUMN kind TEXT NOT NULL DEFAULT 'text'",
        );
      }
      if (!columns.contains('payload')) {
        db.execute('ALTER TABLE messages ADD COLUMN payload TEXT');
      }
      if (!columns.contains('ref')) {
        db.execute('ALTER TABLE messages ADD COLUMN ref TEXT');
      }
      db.execute(
        'CREATE INDEX IF NOT EXISTS messages_ref ON messages(ref) '
        'WHERE ref IS NOT NULL',
      );
    }
    db.userVersion = _schemaVersion;
  }

  /// SQL condition selecting messages shown as bubbles (not responses).
  static const _visible = "kind NOT IN ('vote', 'rsvp', 'close')";

  final String path;
  final Database _db;
  final StreamController<DbChange> _changes = StreamController.broadcast();

  Stream<DbChange> get changes => _changes.stream;

  void _notify(DbTable table, [String? conversationId]) =>
      _changes.add(DbChange(table, conversationId));

  void close() {
    _db.close();
    _changes.close();
  }

  /// Closes and deletes the database and its WAL files.
  void destroy() {
    close();
    for (final suffix in ['', '-wal', '-shm']) {
      final file = File('$path$suffix');
      if (file.existsSync()) file.deleteSync();
    }
  }

  // -- key/value ---------------------------------------------------------------

  String? getValue(String key) {
    final rows = _db.select('SELECT value FROM kv WHERE key = ?', [key]);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  void setValue(String key, String? value) {
    if (value == null) {
      _db.execute('DELETE FROM kv WHERE key = ?', [key]);
    } else {
      _db.execute(
        'INSERT INTO kv (key, value) VALUES (?, ?) '
        'ON CONFLICT(key) DO UPDATE SET value = excluded.value',
        [key, value],
      );
    }
    _notify(DbTable.kv);
  }

  int getInt(String key, [int fallback = 0]) =>
      int.tryParse(getValue(key) ?? '') ?? fallback;

  bool getBool(String key, [bool fallback = false]) {
    final value = getValue(key);
    return value == null ? fallback : value == '1';
  }

  void setBool(String key, bool value) => setValue(key, value ? '1' : '0');

  // -- members -----------------------------------------------------------------

  Member _member(Row row) => Member(
    id: row['id'] as String,
    name: row['name'] as String,
    avatar: row['avatar'] as Uint8List?,
    agreementKey: row['dh_key'] as Uint8List?,
    lastSeen: _date(row['last_seen']),
    joinedAt: _date(row['joined_at']),
    removed: (row['removed'] as int) == 1,
  );

  static DateTime? _date(Object? millis) =>
      millis is int ? DateTime.fromMillisecondsSinceEpoch(millis) : null;

  Member? member(String id) {
    final rows = _db.select('SELECT * FROM members WHERE id = ?', [id]);
    return rows.isEmpty ? null : _member(rows.first);
  }

  List<Member> members({bool includeRemoved = false}) => _db
      .select(
        'SELECT * FROM members ${includeRemoved ? '' : 'WHERE removed = 0'} '
        'ORDER BY name COLLATE NOCASE',
      )
      .map(_member)
      .toList();

  void upsertMember(
    String id, {
    String? name,
    Uint8List? avatar,
    bool clearAvatar = false,
    Uint8List? agreementKey,
    DateTime? lastSeen,
    DateTime? joinedAt,
    bool? removed,
    bool notify = true,
  }) {
    _db.execute('INSERT OR IGNORE INTO members (id) VALUES (?)', [id]);
    final sets = <String>[];
    final args = <Object?>[];
    void set(String column, Object? value) {
      sets.add('$column = ?');
      args.add(value);
    }

    if (name != null) set('name', name);
    if (avatar != null || clearAvatar) set('avatar', avatar);
    if (agreementKey != null) set('dh_key', agreementKey);
    if (lastSeen != null) set('last_seen', lastSeen.millisecondsSinceEpoch);
    if (joinedAt != null) set('joined_at', joinedAt.millisecondsSinceEpoch);
    if (removed != null) set('removed', removed ? 1 : 0);
    if (sets.isNotEmpty) {
      _db.execute('UPDATE members SET ${sets.join(', ')} WHERE id = ?', [
        ...args,
        id,
      ]);
    }
    if (notify) _notify(DbTable.members);
  }

  // -- conversations -------------------------------------------------------------

  Conversation _conversation(Row row) => Conversation(
    id: row['id'] as String,
    type: ConversationType.values.byName(row['type'] as String),
    name: row['name'] as String,
    members: (jsonDecode(row['members'] as String) as List).cast<String>(),
    createdBy: row['created_by'] as String?,
    lastTimestamp: _date(row['last_ts']),
    lastPreview: row['last_preview'] as String?,
    lastSender: row['last_sender'] as String?,
    unread: row['unread'] as int,
    muted: (row['muted'] as int) == 1,
  );

  Conversation? conversation(String id) {
    final rows = _db.select('SELECT * FROM conversations WHERE id = ?', [id]);
    return rows.isEmpty ? null : _conversation(rows.first);
  }

  List<Conversation> conversations() => _db
      .select(
        'SELECT * FROM conversations '
        "ORDER BY (id = 'family') DESC, COALESCE(last_ts, 0) DESC",
      )
      .map(_conversation)
      .toList();

  void upsertConversation({
    required String id,
    required ConversationType type,
    String? name,
    List<String>? members,
    String? createdBy,
  }) {
    _db.execute(
      'INSERT OR IGNORE INTO conversations (id, type) VALUES (?, ?)',
      [id, type.name],
    );
    if (name != null) {
      _db.execute('UPDATE conversations SET name = ? WHERE id = ?', [name, id]);
    }
    if (members != null) {
      _db.execute('UPDATE conversations SET members = ? WHERE id = ?', [
        jsonEncode(members),
        id,
      ]);
    }
    if (createdBy != null) {
      _db.execute('UPDATE conversations SET created_by = ? WHERE id = ?', [
        createdBy,
        id,
      ]);
    }
    _notify(DbTable.conversations);
  }

  void ensureFamilyConversation(String familyName) => upsertConversation(
    id: kFamilyConversationId,
    type: ConversationType.family,
    name: familyName,
  );

  void setMuted(String id, bool muted) {
    _db.execute('UPDATE conversations SET muted = ? WHERE id = ?', [
      muted ? 1 : 0,
      id,
    ]);
    _notify(DbTable.conversations);
  }

  void markRead(String id) {
    final rows = _db.select(
      'SELECT unread FROM conversations WHERE id = ?',
      [id],
    );
    if (rows.isEmpty || rows.first['unread'] == 0) return;
    _db.execute('UPDATE conversations SET unread = 0 WHERE id = ?', [id]);
    _notify(DbTable.conversations);
  }

  int totalUnread() =>
      _db.select('SELECT COALESCE(SUM(unread), 0) AS n FROM conversations')
              .first['n']
          as int;

  /// Recomputes the preview line of a conversation from its newest message.
  void refreshPreview(String conversationId) {
    final rows = _db.select(
      'SELECT * FROM messages WHERE conv = ? AND $_visible '
      'ORDER BY ts DESC LIMIT 1',
      [conversationId],
    );
    if (rows.isEmpty) {
      _db.execute(
        'UPDATE conversations SET last_preview = NULL, last_sender = NULL '
        'WHERE id = ?',
        [conversationId],
      );
    } else {
      final message = _message(rows.first);
      _db.execute(
        'UPDATE conversations SET last_ts = ?, last_preview = ?, '
        'last_sender = ? WHERE id = ?',
        [
          message.timestamp.millisecondsSinceEpoch,
          previewOf(message),
          message.sender,
          conversationId,
        ],
      );
    }
    _notify(DbTable.conversations);
  }

  static String previewOf(ChatMessage message) {
    if (message.deleted) return '\u{1F6AB} Message deleted';
    final poll = message.poll;
    if (poll != null) return '\u{1F4CA} ${poll.question}';
    final call = message.call;
    if (call != null) return '${call.type.emoji} ${call.title}';
    final attachment = message.attachment;
    if (attachment != null) {
      final label = attachment.isImage
          ? '\u{1F4F7} Photo'
          : '\u{1F4CE} ${attachment.name}';
      final text = message.text;
      return text == null || text.isEmpty ? label : '$label · $text';
    }
    return message.text ?? '';
  }

  // -- messages ----------------------------------------------------------------

  ChatMessage _message(Row row) => ChatMessage(
    id: row['id'] as String,
    conversationId: row['conv'] as String,
    sender: row['sender'] as String,
    timestamp: DateTime.fromMillisecondsSinceEpoch(row['ts'] as int),
    status: MessageStatus.values[row['status'] as int],
    text: row['text'] as String?,
    attachment: Attachment.decode(row['attachment'] as String?),
    deleted: (row['deleted'] as int) == 1,
    localPath: row['local_path'] as String?,
    transfer: TransferState.values[row['transfer'] as int],
    kind: MessageKind.parse(row['kind']),
    payload: row['payload'] == null
        ? null
        : jsonDecode(row['payload'] as String) as Map<String, dynamic>,
    ref: row['ref'] as String?,
  );

  ChatMessage? message(String id) {
    final rows = _db.select('SELECT * FROM messages WHERE id = ?', [id]);
    return rows.isEmpty ? null : _message(rows.first);
  }

  /// Newest [limit] messages of a conversation, oldest first.
  List<ChatMessage> messages(String conversationId, {int limit = 100}) => _db
      .select(
        'SELECT * FROM (SELECT * FROM messages WHERE conv = ? AND $_visible '
        'ORDER BY ts DESC LIMIT ?) ORDER BY ts ASC',
        [conversationId, limit],
      )
      .map(_message)
      .toList();

  int messageCount(String conversationId) =>
      _db.select(
            'SELECT COUNT(*) AS n FROM messages WHERE conv = ? AND $_visible',
            [conversationId],
          ).first['n']
          as int;

  /// Votes, RSVPs and close events for the poll or call [ref], oldest first.
  List<ChatMessage> responsesTo(String ref) => _db
      .select(
        'SELECT * FROM messages WHERE ref = ? AND deleted = 0 ORDER BY ts ASC',
        [ref],
      )
      .map(_message)
      .toList();

  List<ChatMessage> pendingMessages() => _db
      .select(
        'SELECT * FROM messages WHERE status = ? ORDER BY ts ASC',
        [MessageStatus.pending.index],
      )
      .map(_message)
      .toList();

  List<ChatMessage> mediaMessages(String conversationId) => _db
      .select(
        'SELECT * FROM messages WHERE conv = ? AND attachment IS NOT NULL '
        'AND deleted = 0 ORDER BY ts DESC',
        [conversationId],
      )
      .map(_message)
      .toList();

  /// Inserts a message. Returns false if it was already stored.
  bool insertMessage(ChatMessage message) {
    _db.execute(
      'INSERT OR IGNORE INTO messages (id, conv, sender, ts, status, text, '
      'attachment, deleted, local_path, transfer, kind, payload, ref) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        message.id,
        message.conversationId,
        message.sender,
        message.timestamp.millisecondsSinceEpoch,
        message.status.index,
        message.text,
        message.attachment?.encode(),
        message.deleted ? 1 : 0,
        message.localPath,
        message.transfer.index,
        message.kind.name,
        message.payload == null ? null : jsonEncode(message.payload),
        message.ref,
      ],
    );
    final inserted = _db.updatedRows > 0;
    if (inserted) _notify(DbTable.messages, message.conversationId);
    return inserted;
  }

  void incrementUnread(String conversationId) => _db.execute(
    'UPDATE conversations SET unread = unread + 1 WHERE id = ?',
    [conversationId],
  );

  void markSent(String id, {required int seq, required DateTime timestamp}) {
    _db.execute(
      'UPDATE messages SET status = ?, seq = ?, ts = ? WHERE id = ?',
      [MessageStatus.sent.index, seq, timestamp.millisecondsSinceEpoch, id],
    );
    final conv = message(id)?.conversationId;
    _notify(DbTable.messages, conv);
  }

  void setStatus(String id, MessageStatus status) {
    _db.execute('UPDATE messages SET status = ? WHERE id = ?', [
      status.index,
      id,
    ]);
    _notify(DbTable.messages, message(id)?.conversationId);
  }

  void updateAttachment(String id, Attachment attachment) {
    _db.execute('UPDATE messages SET attachment = ? WHERE id = ?', [
      attachment.encode(),
      id,
    ]);
    _notify(DbTable.messages, message(id)?.conversationId);
  }

  void setTransfer(String id, TransferState state, {String? localPath}) {
    _db.execute(
      'UPDATE messages SET transfer = ?, '
      'local_path = COALESCE(?, local_path) WHERE id = ?',
      [state.index, localPath, id],
    );
    _notify(DbTable.messages, message(id)?.conversationId);
  }

  /// Marks a message deleted and returns its local file path, if any.
  String? markDeleted(String id) {
    final existing = message(id);
    if (existing == null) return null;
    _db.execute(
      'UPDATE messages SET deleted = 1, text = NULL, attachment = NULL, '
      'payload = NULL, local_path = NULL, transfer = 0 WHERE id = ?',
      [id],
    );
    _notify(DbTable.messages, existing.conversationId);
    return existing.localPath;
  }

  /// Removes a message from this device only.
  String? removeLocally(String id) {
    final existing = message(id);
    if (existing == null) return null;
    _db.execute('DELETE FROM messages WHERE id = ?', [id]);
    _notify(DbTable.messages, existing.conversationId);
    refreshPreview(existing.conversationId);
    return existing.localPath;
  }

  /// Deletes all messages of a conversation on this device and returns the
  /// paths of their local files.
  List<String> clearConversation(String conversationId) {
    final paths = _db
        .select(
          'SELECT local_path FROM messages WHERE conv = ? '
          'AND local_path IS NOT NULL',
          [conversationId],
        )
        .map((r) => r['local_path'] as String)
        .toList();
    _db.execute('DELETE FROM messages WHERE conv = ?', [conversationId]);
    _notify(DbTable.messages, conversationId);
    refreshPreview(conversationId);
    return paths;
  }
}
