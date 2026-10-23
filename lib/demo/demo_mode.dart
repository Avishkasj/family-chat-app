// Demo mode for App Store screenshots.
//
// Only compiled into builds made with `--dart-define=FAMNEST_DEMO=true`
// (see tool/capture_store_screenshots.sh). It fills the local database with
// a sample family and opens the screen named in `demo.json`. Normal builds
// never include any of this: every entry point checks [kDemoMode], a
// compile-time constant.
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../data/local_database.dart';
import '../data/models.dart';
import '../services/chat_service.dart';
import '../shared/protocol.dart';

const bool kDemoMode = bool.fromEnvironment('FAMNEST_DEMO');

/// What to show, read from `<data dir>/demo.json` at launch.
class DemoConfig {
  const DemoConfig({this.route = '/', this.sheet, this.tab = 0});

  factory DemoConfig.fromJson(Map<String, dynamic> json) => DemoConfig(
    route: json['route'] as String? ?? '/',
    sheet: json['sheet'] as String?,
    tab: json['tab'] as int? ?? 0,
  );

  final String route;

  /// `actions` opens the family-call sheet in a chat.
  final String? sheet;

  /// Initial home tab (0 chats, 1 family, 2 settings).
  final int tab;
}

/// The active demo configuration, or null outside demo mode.
DemoConfig? demoConfig;

// Sample family members (the device itself is "Nisha").
const _mum = 'a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1';
const _dad = 'b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2';
const _grandma = 'c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3';
const _kavin = 'd4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4';
const _tripGroup = 'grp-weekend-trip';

/// Online members shown in the demo.
const demoOnline = {_mum, _grandma, _kavin};

/// Loads `demo.json` and seeds the sample family once.
Future<void> setUpDemo({
  required String dataDirectory,
  required LocalDatabase db,
  required ChatService chat,
}) async {
  final file = File(p.join(dataDirectory, 'demo.json'));
  final json = file.existsSync()
      ? jsonDecode(file.readAsStringSync()) as Map<String, dynamic>
      : <String, dynamic>{};
  demoConfig = DemoConfig.fromJson(json);

  if (!db.getBool('demo_seeded')) {
    _seed(db, chat, dataDirectory, json['photo'] as Map<String, dynamic>?);
    db.setBool('demo_seeded', true);
  }
  chat.online.value = {...demoOnline, chat.myId};
  chat.link.value = const LinkState(LinkStatus.connected);
}

void _seed(
  LocalDatabase db,
  ChatService chat,
  String dataDirectory,
  Map<String, dynamic>? photo,
) {
  final me = chat.myId;
  final now = DateTime.now();
  DateTime at(int hour, int minute) =>
      DateTime(now.year, now.month, now.day, hour, minute);

  db
    ..setValue(Keys.familyId, 'demo-family')
    ..setValue(Keys.familyName, 'Perera Family')
    ..setValue(Keys.hubHost, '192.168.1.20')
    ..setValue(Keys.hubPort, '$kHubPort')
    ..setBool(Keys.isHubOwner, false)
    ..setBool(Keys.appLock, true)
    ..ensureFamilyConversation('Perera Family');

  db.upsertMember(me, name: 'Nisha', joinedAt: at(7, 0));
  for (final (id, name, seen) in [
    (_mum, 'Mum', at(9, 40)),
    (_dad, 'Dad', at(9, 36)),
    (_grandma, 'Grandma', at(9, 39)),
    (_kavin, 'Kavin', at(9, 41)),
  ]) {
    db.upsertMember(id, name: name, lastSeen: seen, joinedAt: at(7, 0));
  }

  var n = 0;
  String add(
    String conv,
    String from,
    DateTime time, {
    String? text,
    MessageKind kind = MessageKind.text,
    Map<String, dynamic>? payload,
    String? ref,
    Attachment? attachment,
    String? localPath,
  }) {
    final id = 'demo-${(n++).toString().padLeft(4, '0')}';
    db.insertMessage(
      ChatMessage(
        id: id,
        conversationId: conv,
        sender: from,
        timestamp: time,
        status: MessageStatus.sent,
        text: text,
        attachment: attachment,
        deleted: false,
        localPath: localPath,
        transfer: localPath == null ? TransferState.none : TransferState.done,
        kind: kind,
        payload: payload,
        ref: ref,
      ),
    );
    return id;
  }

  // -- Family chat --------------------------------------------------------
  const family = kFamilyConversationId;
  add(family, _dad, at(7, 40), text: 'Morning all! Kettle is on \u2615');
  add(family, _kavin, at(7, 46), text: 'Five more minutes \u{1F634}');
  add(family, _mum, at(7, 50), text: 'Kavin, the school bus is at 8! \u{1F68C}');
  add(family, _grandma, at(7, 58),
      text: "Good morning everyone \u2600\uFE0F Who's coming for tea later?");
  final lunch = add(family, _mum, at(9, 15),
      kind: MessageKind.call,
      payload: const CallData(
        type: CallType.lunch,
        title: 'Lunch is ready!',
        note: 'Rice & curry with dhal \u{1F35B}',
      ).toJson());
  for (final (who, answer, minute) in [
    (_kavin, CallAnswer.coming, 16),
    (_dad, CallAnswer.soon, 16),
    (_grandma, CallAnswer.coming, 17),
  ]) {
    add(family, who, at(9, minute),
        kind: MessageKind.rsvp,
        payload: {'answer': answer.name},
        ref: lunch);
  }
  if (photo != null) {
    final source = File(p.join(dataDirectory, photo['file'] as String));
    final dir = Directory(p.join(dataDirectory, 'files', 'demo-photo'))
      ..createSync(recursive: true);
    final path = p.join(dir.path, 'garden.jpg');
    source.copySync(path);
    add(family, _dad, at(9, 24),
        text: 'Sunrise from the garden this morning \u{1F304}',
        attachment: Attachment(
          fileId: 'demo-photo',
          name: 'garden.jpg',
          size: source.lengthSync(),
          mime: 'image/jpeg',
          key: '',
          isImage: true,
          thumbnail: photo['thumb'] as String?,
          width: photo['w'] as int?,
          height: photo['h'] as int?,
        ),
        localPath: path);
  }

  // -- Weekend trip group with a poll ---------------------------------------
  db.upsertConversation(
    id: _tripGroup,
    type: ConversationType.group,
    name: 'Weekend trip \u{1F334}',
    members: [me, _mum, _dad, _kavin],
    createdBy: _dad,
  );
  final poll = add(_tripGroup, _dad, at(9, 20),
      kind: MessageKind.poll,
      payload: const PollData(
        question: 'Where should we go this weekend?',
        options: [
          'Kandy \u{1F3DE}️',
          'Galle Fort \u{1F3F0}',
          'Nuwara Eliya \u{1F343}',
        ],
        multiple: false,
      ).toJson());
  for (final (who, choice, minute) in [
    (_mum, 0, 21),
    (_kavin, 1, 21),
    (_dad, 0, 22),
    (me, 0, 23),
  ]) {
    add(_tripGroup, who, at(9, minute),
        kind: MessageKind.vote,
        payload: {
          'choices': [choice],
        },
        ref: poll);
  }
  add(_tripGroup, _mum, at(9, 24),
      text: "Kandy it is! I'll pack the snacks \u{1F96A}");
  add(_tripGroup, _kavin, at(9, 30),
      text: 'Can we stop for ice cream on the way? \u{1F366}');

  // -- Direct chats ---------------------------------------------------------
  final withMum = chat.openDirect(_mum);
  add(withMum, _mum, at(9, 2),
      text: 'Can you pick up bread on your way home? \u{1F35E}');
  add(withMum, me, at(9, 5), text: 'Sure! Anything else?');
  add(withMum, _mum, at(9, 6), text: 'Some milk too, thank you ❤️');
  add(withMum, me, at(9, 7), text: 'Got it \u{1F44D}');
  final withDad = chat.openDirect(_dad);
  add(withDad, _dad, at(9, 35), text: 'Your bike is fixed! \u{1F6B2}');

  for (final conv in [family, _tripGroup, withMum, withDad]) {
    db.refreshPreview(conv);
  }
  db
    ..incrementUnread(_tripGroup)
    ..incrementUnread(_tripGroup)
    ..incrementUnread(withDad);
}
