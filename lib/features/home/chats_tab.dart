import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/providers.dart';
import '../../core/router/routes.dart';
import '../../core/theme/extension.dart';
import '../../data/models.dart';
import '../../widgets/connection_banner.dart';
import '../../widgets/member_avatar.dart';

class ChatsTab extends ConsumerWidget {
  const ChatsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversations = ref.watch(conversationsProvider);
    final me = ref.watch(myIdProvider);
    // Hide empty direct chats and groups this device has left.
    final visible = conversations
        .where(
          (c) =>
              c.type == ConversationType.family ||
              (c.type == ConversationType.group && c.members.contains(me)) ||
              c.lastTimestamp != null,
        )
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          ref.watch(familyNameProvider),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: [
          const ConnectionBanner(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 88),
              itemCount: visible.length,
              itemBuilder: (context, i) =>
                  _ConversationTile(conversation: visible[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationTile extends ConsumerWidget {
  const _ConversationTile({required this.conversation});

  final Conversation conversation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final scheme = context.colorScheme;
    final me = ref.watch(myIdProvider);
    final title = ref.watch(conversationTitleProvider(conversation.id));
    final typing = ref.watch(typingProvider)[conversation.id] ?? const {};
    final lastSender = conversation.lastSender;
    final senderName = lastSender == null
        ? null
        : lastSender == me
        ? l10n.you
        : ref.watch(memberProvider(lastSender))?.displayName;

    String subtitle;
    if (typing.isNotEmpty) {
      subtitle = l10n.typing;
    } else if (conversation.lastPreview == null) {
      subtitle = conversation.isFamily ? l10n.everyone : l10n.noMessagesYet;
    } else if (conversation.type != ConversationType.direct &&
        senderName != null) {
      subtitle = '$senderName: ${conversation.lastPreview}';
    } else {
      subtitle = conversation.lastPreview!;
    }
    final unread = conversation.unread;
    final time = conversation.lastTimestamp;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: ConversationAvatar(conversation: conversation),
      title: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          if (conversation.muted)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Icon(
                Icons.notifications_off_outlined,
                size: 16,
                color: scheme.onSurfaceVariant,
              ),
            ),
          if (time != null)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                context.formatListTime(time),
                style: context.textTheme.labelSmall?.copyWith(
                  color: unread > 0 ? scheme.primary : scheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
      subtitle: Row(
        children: [
          Expanded(
            child: Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: typing.isNotEmpty
                  ? TextStyle(
                      color: scheme.primary,
                      fontStyle: FontStyle.italic,
                    )
                  : null,
            ),
          ),
          if (unread > 0)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                unread > 99 ? '99+' : '$unread',
                style: context.textTheme.labelSmall?.copyWith(
                  color: scheme.onPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
      onTap: () => context.push(Routes.chat(conversation.id)),
    );
  }
}
