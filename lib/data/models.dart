import 'dart:convert';
import 'dart:typed_data';

import '../shared/protocol.dart';

enum ConversationType { family, direct, group }

enum MessageStatus { pending, sent, failed }

enum TransferState { none, active, done, failed }

/// What a message carries. [vote], [rsvp] and [close] are responses to an
/// earlier poll or call ([ChatMessage.ref]); they aren't shown as bubbles but
/// update the card they refer to.
enum MessageKind {
  text,
  poll,
  call,
  vote,
  rsvp,
  close;

  bool get isResponse => this == vote || this == rsvp || this == close;

  static MessageKind parse(Object? value) => MessageKind.values.firstWhere(
    (k) => k.name == value,
    orElse: () => MessageKind.text,
  );
}

/// Built-in family calls. [custom] uses the sender's own title.
enum CallType {
  breakfast('\u{1F373}'),
  lunch('\u{1F35B}'),
  tea('\u{2615}'),
  dinner('\u{1F37D}\u{FE0F}'),
  ready('\u{1F514}'),
  comeHere('\u{1F4E3}'),
  custom('\u{1F4E2}');

  const CallType(this.emoji);
  final String emoji;

  static CallType parse(Object? value) => CallType.values.firstWhere(
    (t) => t.name == value,
    orElse: () => CallType.custom,
  );
}

/// Answers to a family call.
enum CallAnswer {
  coming('\u{1F3C3}'),
  soon('\u{23F3}'),
  skip('\u{1F645}');

  const CallAnswer(this.emoji);
  final String emoji;

  static CallAnswer? parse(Object? value) =>
      CallAnswer.values.where((a) => a.name == value).firstOrNull;
}

class PollData {
  const PollData({
    required this.question,
    required this.options,
    required this.multiple,
  });

  factory PollData.fromJson(Map<String, dynamic> json) => PollData(
    question: json['q'] as String? ?? '',
    options: (json['options'] as List? ?? const []).cast<String>(),
    multiple: json['multi'] as bool? ?? false,
  );

  final String question;
  final List<String> options;
  final bool multiple;

  Map<String, dynamic> toJson() => {
    'q': question,
    'options': options,
    'multi': multiple,
  };
}

class CallData {
  const CallData({required this.type, required this.title, this.note});

  factory CallData.fromJson(Map<String, dynamic> json) => CallData(
    type: CallType.parse(json['type']),
    title: json['title'] as String? ?? '',
    note: json['note'] as String?,
  );

  final CallType type;

  /// Title as written by the sender (used for previews and notifications).
  final String title;
  final String? note;

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'title': title,
    'note': ?note,
  };
}

class Member {
  const Member({
    required this.id,
    required this.name,
    required this.avatar,
    required this.agreementKey,
    required this.lastSeen,
    required this.joinedAt,
    required this.removed,
  });

  final String id;
  final String name;
  final Uint8List? avatar;
  final Uint8List? agreementKey;
  final DateTime? lastSeen;
  final DateTime? joinedAt;
  final bool removed;

  String get displayName => name.isEmpty ? 'Family member' : name;

  String get initials {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    final letters = parts.take(2).map((p) => p.isEmpty ? '' : p[0]).join();
    return letters.toUpperCase();
  }
}

class Conversation {
  const Conversation({
    required this.id,
    required this.type,
    required this.name,
    required this.members,
    required this.createdBy,
    required this.lastTimestamp,
    required this.lastPreview,
    required this.lastSender,
    required this.unread,
    required this.muted,
  });

  final String id;
  final ConversationType type;
  final String name;
  final List<String> members;
  final String? createdBy;
  final DateTime? lastTimestamp;
  final String? lastPreview;
  final String? lastSender;
  final int unread;
  final bool muted;

  bool get isFamily => id == kFamilyConversationId;

  /// The other member of a direct conversation.
  String? peerOf(String me) {
    final ids = directConversationMembers(id);
    if (ids == null) return null;
    return ids.firstWhere((id) => id != me, orElse: () => me);
  }
}

class Attachment {
  const Attachment({
    required this.fileId,
    required this.name,
    required this.size,
    required this.mime,
    required this.key,
    required this.isImage,
    this.thumbnail,
    this.width,
    this.height,
  });

  factory Attachment.fromJson(Map<String, dynamic> json) => Attachment(
    fileId: json['fileId'] as String,
    name: json['name'] as String? ?? 'file',
    size: json['size'] as int? ?? 0,
    mime: json['mime'] as String? ?? 'application/octet-stream',
    key: json['key'] as String,
    isImage: json['image'] as bool? ?? false,
    thumbnail: json['thumb'] as String?,
    width: json['w'] as int?,
    height: json['h'] as int?,
  );

  final String fileId;
  final String name;
  final int size;
  final String mime;

  /// Base64 AES-256 key the file chunks are encrypted with.
  final String key;
  final bool isImage;

  /// Tiny base64 PNG preview shown while the full image downloads.
  final String? thumbnail;
  final int? width;
  final int? height;

  Map<String, dynamic> toJson() => {
    'fileId': fileId,
    'name': name,
    'size': size,
    'mime': mime,
    'key': key,
    'image': isImage,
    'thumb': ?thumbnail,
    'w': ?width,
    'h': ?height,
  };

  String encode() => jsonEncode(toJson());

  static Attachment? decode(String? value) => value == null
      ? null
      : Attachment.fromJson(jsonDecode(value) as Map<String, dynamic>);
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.sender,
    required this.timestamp,
    required this.status,
    required this.text,
    required this.attachment,
    required this.deleted,
    required this.localPath,
    required this.transfer,
    this.kind = MessageKind.text,
    this.payload,
    this.ref,
  });

  final String id;
  final String conversationId;
  final String sender;
  final DateTime timestamp;
  final MessageStatus status;
  final String? text;
  final Attachment? attachment;
  final bool deleted;
  final String? localPath;
  final TransferState transfer;
  final MessageKind kind;

  /// Kind-specific data: [PollData] / [CallData] JSON, or a response
  /// (`{"choices": [..]}` for votes, `{"answer": ".."}` for RSVPs).
  final Map<String, dynamic>? payload;

  /// Id of the poll or call a response refers to.
  final String? ref;

  PollData? get poll =>
      kind == MessageKind.poll && payload != null ? PollData.fromJson(payload!) : null;

  CallData? get call =>
      kind == MessageKind.call && payload != null ? CallData.fromJson(payload!) : null;
}


/// Current result of a poll, from its responses (latest vote per member wins;
/// votes cast after the author closed the poll are ignored).
class PollTally {
  PollTally._(this.votes, this.closed);

  factory PollTally.from(ChatMessage poll, List<ChatMessage> responses) {
    final options = poll.poll?.options.length ?? 0;
    final votes = <String, Set<int>>{};
    var closed = false;
    for (final response in responses) {
      if (response.kind == MessageKind.close && response.sender == poll.sender) {
        closed = true;
      } else if (response.kind == MessageKind.vote && !closed) {
        final choices = (response.payload?['choices'] as List? ?? const [])
            .whereType<int>()
            .where((i) => i >= 0 && i < options)
            .toSet();
        votes[response.sender] = choices;
      }
    }
    votes.removeWhere((_, choices) => choices.isEmpty);
    return PollTally._(votes, closed);
  }

  /// Member id -> chosen option indexes.
  final Map<String, Set<int>> votes;
  final bool closed;

  List<String> votersFor(int option) => [
    for (final entry in votes.entries)
      if (entry.value.contains(option)) entry.key,
  ];

  Set<int> choicesOf(String memberId) => votes[memberId] ?? const {};
}

/// Who answered a family call and how (latest answer per member wins).
class CallReplies {
  CallReplies._(this.answers);

  factory CallReplies.from(List<ChatMessage> responses) {
    final answers = <String, CallAnswer>{};
    for (final response in responses) {
      if (response.kind != MessageKind.rsvp) continue;
      final answer = CallAnswer.parse(response.payload?['answer']);
      if (answer != null) answers[response.sender] = answer;
    }
    return CallReplies._(answers);
  }

  final Map<String, CallAnswer> answers;

  List<String> membersWith(CallAnswer answer) => [
    for (final entry in answers.entries)
      if (entry.value == answer) entry.key,
  ];
}
