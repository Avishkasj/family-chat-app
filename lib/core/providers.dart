import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local_database.dart';
import '../data/models.dart';
import '../services/app_lock.dart';
import '../services/chat_service.dart';
import '../services/hub_host/hub_host.dart';
import '../shared/hub/hub_server.dart';
import 'app_services.dart';

final appServicesProvider = Provider<AppServices>(
  (ref) => throw UnimplementedError('Overridden at startup'),
);

final chatServiceProvider = Provider<ChatService>(
  (ref) => ref.watch(appServicesProvider).chat,
);

final databaseProvider = Provider<LocalDatabase>(
  (ref) => ref.watch(appServicesProvider).db,
);

final hubHostProvider = Provider<HubHost>(
  (ref) => ref.watch(appServicesProvider).hubHost,
);

final appLockProvider = Provider<AppLock>(
  (ref) => ref.watch(appServicesProvider).appLock,
);

final myIdProvider = Provider<String>(
  (ref) => ref.watch(appServicesProvider).keys.deviceId,
);

/// Exposes a [ValueListenable] as a provider that rebuilds on change.
T _watchListenable<T>(Ref ref, ValueListenable<T> listenable) {
  void listener() => ref.invalidateSelf();
  listenable.addListener(listener);
  ref.onDispose(() => listenable.removeListener(listener));
  return listenable.value;
}

/// Re-runs a database query whenever one of [tables] changes.
T _query<T>(
  Ref ref,
  Set<DbTable> tables,
  T Function(LocalDatabase db) query, {
  String? conversationId,
}) {
  final db = ref.watch(databaseProvider);
  final subscription = db.changes
      .where(
        (c) =>
            tables.contains(c.table) &&
            (conversationId == null ||
                c.conversationId == null ||
                c.conversationId == conversationId),
      )
      .listen((_) => ref.invalidateSelf());
  ref.onDispose(subscription.cancel);
  return query(db);
}

final linkStateProvider = Provider<LinkState>(
  (ref) => _watchListenable(ref, ref.watch(chatServiceProvider).link),
);

final onlineProvider = Provider<Set<String>>(
  (ref) => _watchListenable(ref, ref.watch(chatServiceProvider).online),
);

final typingProvider = Provider<Map<String, Set<String>>>(
  (ref) => _watchListenable(ref, ref.watch(chatServiceProvider).typing),
);

final transferProgressProvider = Provider<Map<String, double>>(
  (ref) => _watchListenable(ref, ref.watch(chatServiceProvider).progress),
);

final hubStatusProvider = Provider<HubStatus>(
  (ref) => _watchListenable(ref, ref.watch(hubHostProvider).status),
);

final settingProvider = Provider.family<String?, String>(
  (ref, key) => _query(ref, {DbTable.kv}, (db) => db.getValue(key)),
);

final familyNameProvider = Provider<String>(
  (ref) => ref.watch(settingProvider(Keys.familyName)) ?? 'Family',
);

final isHubOwnerProvider = Provider<bool>(
  (ref) => ref.watch(settingProvider(Keys.isHubOwner)) == '1',
);

final conversationsProvider = Provider<List<Conversation>>(
  (ref) => _query(ref, {DbTable.conversations}, (db) => db.conversations()),
);

final conversationProvider = Provider.family<Conversation?, String>(
  (ref, id) =>
      _query(ref, {DbTable.conversations}, (db) => db.conversation(id)),
);

final totalUnreadProvider = Provider<int>(
  (ref) => ref
      .watch(conversationsProvider)
      .fold(0, (sum, conversation) => sum + conversation.unread),
);

/// All members ever seen, including removed ones (to label old messages).
final allMembersProvider = Provider<Map<String, Member>>(
  (ref) => _query(ref, {DbTable.members}, (db) {
    return {for (final m in db.members(includeRemoved: true)) m.id: m};
  }),
);

/// Current family members other than this device.
final familyMembersProvider = Provider<List<Member>>((ref) {
  final me = ref.watch(myIdProvider);
  return ref
      .watch(allMembersProvider)
      .values
      .where((m) => !m.removed && m.id != me)
      .toList()
    ..sort(
      (a, b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
    );
});

final memberProvider = Provider.family<Member?, String>(
  (ref, id) => ref.watch(allMembersProvider)[id],
);

final meProvider = Provider<Member?>(
  (ref) => ref.watch(memberProvider(ref.watch(myIdProvider))),
);

final messagesProvider = Provider.autoDispose
    .family<List<ChatMessage>, ({String conversationId, int limit})>(
      (ref, args) => _query(
        ref,
        {DbTable.messages},
        (db) => db.messages(args.conversationId, limit: args.limit),
        conversationId: args.conversationId,
      ),
    );

final mediaProvider = Provider.autoDispose.family<List<ChatMessage>, String>(
  (ref, id) => _query(
    ref,
    {DbTable.messages},
    (db) => db.mediaMessages(id),
    conversationId: id,
  ),
);

/// Display title for a conversation.
final conversationTitleProvider = Provider.family<String, String>((ref, id) {
  final conversation = ref.watch(conversationProvider(id));
  if (conversation == null) return '';
  switch (conversation.type) {
    case ConversationType.family:
      return ref.watch(familyNameProvider);
    case ConversationType.group:
      return conversation.name;
    case ConversationType.direct:
      final peer = conversation.peerOf(ref.watch(myIdProvider));
      return peer == null
          ? ''
          : ref.watch(memberProvider(peer))?.displayName ?? 'Family member';
  }
});

/// Votes / RSVPs / close events for a poll or call card.
final responsesProvider = Provider.autoDispose
    .family<List<ChatMessage>, ({String conversationId, String ref})>(
      (ref, args) => _query(
        ref,
        {DbTable.messages},
        (db) => db.responsesTo(args.ref),
        conversationId: args.conversationId,
      ),
    );
