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

class FamilyTab extends ConsumerWidget {
  const FamilyTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final members = ref.watch(familyMembersProvider);
    final online = ref.watch(onlineProvider);
    final me = ref.watch(meProvider);
    final sorted = [...members]
      ..sort((a, b) {
        final ao = online.contains(a.id) ? 0 : 1;
        final bo = online.contains(b.id) ? 0 : 1;
        return ao != bo ? ao - bo : a.displayName.compareTo(b.displayName);
      });

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.family,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: [
          const ConnectionBanner(),
          Expanded(
            child: ListView(
              children: [
                if (me != null)
                  ListTile(
                    leading: MemberAvatar(memberId: me.id),
                    title: Text('${me.displayName} (${l10n.you})'),
                    subtitle: Text(l10n.editProfile),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(Routes.profile),
                  ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                  child: Text(
                    l10n.membersCount(members.length + 1),
                    style: context.textTheme.labelLarge?.copyWith(
                      color: context.colorScheme.primary,
                    ),
                  ),
                ),
                for (final member in sorted)
                  FamilyMemberTile(
                    member: member,
                    onTap: () {
                      final id = ref
                          .read(chatServiceProvider)
                          .openDirect(member.id);
                      context.push(Routes.chat(id));
                    },
                  ),
                if (members.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      l10n.noFamilyMembersYet,
                      textAlign: TextAlign.center,
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FamilyMemberTile extends ConsumerWidget {
  const FamilyMemberTile({
    required this.member,
    super.key,
    this.onTap,
    this.trailing,
  });

  final Member member;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(onlineProvider).contains(member.id);
    return ListTile(
      leading: MemberAvatar(memberId: member.id, showPresence: true),
      title: Text(member.displayName),
      subtitle: Text(
        online ? context.l10n.online : context.formatLastSeen(member.lastSeen),
        style: online ? TextStyle(color: context.colorScheme.primary) : null,
      ),
      trailing: trailing,
      onTap: onTap,
    );
  }
}
