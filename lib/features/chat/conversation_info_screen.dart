import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_filex/open_filex.dart';

import '../../core/format.dart';
import '../../core/providers.dart';
import '../../core/router/routes.dart';
import '../../core/theme/extension.dart';
import '../../data/models.dart';
import '../../widgets/member_avatar.dart';
import '../home/family_tab.dart';

class ConversationInfoScreen extends ConsumerWidget {
  const ConversationInfoScreen({required this.conversationId, super.key});

  final String conversationId;

  Future<bool> _confirm(
    BuildContext context,
    String message,
    String action,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.colorScheme.error,
              minimumSize: const Size(64, 40),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final conversation = ref.watch(conversationProvider(conversationId));
    if (conversation == null) return Scaffold(appBar: AppBar());
    final me = ref.watch(myIdProvider);
    final title = ref.watch(conversationTitleProvider(conversationId));
    final chat = ref.read(chatServiceProvider);
    final media = ref.watch(mediaProvider(conversationId));
    final images = media
        .where(
          (m) =>
              m.attachment!.isImage &&
              m.localPath != null &&
              File(m.localPath!).existsSync(),
        )
        .toList();
    final files = media.where((m) => !m.attachment!.isImage).toList();

    final List<Member> members;
    switch (conversation.type) {
      case ConversationType.family:
        members = [
          ?ref.watch(meProvider),
          ...ref.watch(familyMembersProvider),
        ];
      case ConversationType.group:
        final all = ref.watch(allMembersProvider);
        members = [
          for (final id in conversation.members) ?all[id],
        ];
      case ConversationType.direct:
        members = const [];
    }
    final peerId = conversation.peerOf(me);
    final isGroupMember =
        conversation.type == ConversationType.group &&
        conversation.members.contains(me);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          conversation.type == ConversationType.direct
              ? l10n.contactInfo
              : l10n.groupInfo,
        ),
        actions: [
          if (isGroupMember)
            IconButton(
              tooltip: l10n.editGroup,
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push(Routes.editGroup(conversationId)),
            ),
        ],
      ),
      body: ListView(
        children: [
          const SizedBox(height: 24),
          Center(
            child: conversation.type == ConversationType.direct
                ? MemberAvatar(memberId: peerId ?? '', radius: 52)
                : ConversationAvatar(conversation: conversation, radius: 52),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: context.textTheme.headlineSmall,
          ),
          if (peerId != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                ref.watch(onlineProvider).contains(peerId)
                    ? l10n.online
                    : context.formatLastSeen(
                        ref.watch(memberProvider(peerId))?.lastSeen,
                      ),
                textAlign: TextAlign.center,
              ),
            ),
          if (conversation.type == ConversationType.direct)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock_rounded,
                    size: 14,
                    color: context.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      l10n.directEncrypted,
                      textAlign: TextAlign.center,
                      style: context.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_off_outlined),
            title: Text(l10n.mute),
            value: conversation.muted,
            onChanged: (value) =>
                ref.read(databaseProvider).setMuted(conversationId, value),
          ),
          if (images.isNotEmpty || files.isNotEmpty) ...[
            const Divider(),
            _SectionHeader(l10n.sharedMedia),
            if (images.isNotEmpty)
              SizedBox(
                height: 96,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: images.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final path = images[i].localPath!;
                    return GestureDetector(
                      onTap: () => context.push(Routes.viewer, extra: path),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(path),
                          width: 96,
                          height: 96,
                          fit: BoxFit.cover,
                          cacheWidth: 240,
                        ),
                      ),
                    );
                  },
                ),
              ),
            for (final file in files.take(20))
              ListTile(
                leading: const Icon(Icons.insert_drive_file_outlined),
                title: Text(
                  file.attachment!.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${formatBytes(file.attachment!.size)} · '
                  '${context.formatListTime(file.timestamp)}',
                ),
                onTap: file.localPath == null
                    ? null
                    : () => OpenFilex.open(file.localPath!),
              ),
          ],
          if (members.isNotEmpty) ...[
            const Divider(),
            _SectionHeader(l10n.membersCount(members.length)),
            for (final member in members)
              FamilyMemberTile(
                member: member,
                onTap: member.id == me
                    ? null
                    : () {
                        final id = chat.openDirect(member.id);
                        context.push(Routes.chat(id));
                      },
              ),
          ],
          const Divider(),
          ListTile(
            leading: Icon(
              Icons.cleaning_services_outlined,
              color: context.colorScheme.error,
            ),
            title: Text(
              l10n.clearChat,
              style: TextStyle(color: context.colorScheme.error),
            ),
            onTap: () async {
              if (await _confirm(context, l10n.clearChatConfirm, l10n.delete)) {
                await chat.clearConversation(conversationId);
              }
            },
          ),
          if (isGroupMember)
            ListTile(
              leading: Icon(
                Icons.logout_rounded,
                color: context.colorScheme.error,
              ),
              title: Text(
                l10n.leaveGroup,
                style: TextStyle(color: context.colorScheme.error),
              ),
              onTap: () async {
                if (!await _confirm(
                  context,
                  l10n.leaveGroupConfirm,
                  l10n.leaveGroup,
                )) {
                  return;
                }
                try {
                  await chat.leaveGroup(conversationId);
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.notConnectedAction)),
                    );
                  }
                }
              },
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Text(
        text,
        style: context.textTheme.labelLarge?.copyWith(
          color: context.colorScheme.primary,
        ),
      ),
    );
  }
}
