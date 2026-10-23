import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/router/routes.dart';
import '../../core/theme/extension.dart';
import '../../demo/demo_mode.dart';
import '../settings/settings_tab.dart';
import 'chats_tab.dart';
import 'family_tab.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _index = kDemoMode ? demoConfig?.tab ?? 0 : 0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final unread = ref.watch(totalUnreadProvider);
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [ChatsTab(), FamilyTab(), SettingsTab()],
      ),
      floatingActionButton: _index == 0
          ? FloatingActionButton(
              tooltip: l10n.newChat,
              onPressed: () => showNewChatSheet(context, ref),
              child: const Icon(Icons.edit_square),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text(unread > 99 ? '99+' : '$unread'),
              child: const Icon(Icons.chat_bubble_outline_rounded),
            ),
            selectedIcon: Badge(
              isLabelVisible: unread > 0,
              label: Text(unread > 99 ? '99+' : '$unread'),
              child: const Icon(Icons.chat_bubble_rounded),
            ),
            label: l10n.chats,
          ),
          NavigationDestination(
            icon: const Icon(Icons.people_outline_rounded),
            selectedIcon: const Icon(Icons.people_rounded),
            label: l10n.family,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: l10n.settings,
          ),
        ],
      ),
    );
  }
}

Future<void> showNewChatSheet(BuildContext context, WidgetRef ref) {
  final l10n = context.l10n;
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => Consumer(
      builder: (context, ref, _) {
        final members = ref.watch(familyMembersProvider);
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          builder: (context, controller) => ListView(
            controller: controller,
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: context.colorScheme.tertiaryContainer,
                  child: Icon(
                    Icons.group_add_rounded,
                    color: context.colorScheme.onTertiaryContainer,
                  ),
                ),
                title: Text(l10n.newGroup),
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.push(Routes.newGroup);
                },
              ),
              const Divider(),
              for (final member in members)
                FamilyMemberTile(
                  member: member,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    final id = ref
                        .read(chatServiceProvider)
                        .openDirect(member.id);
                    context.push(Routes.chat(id));
                  },
                ),
              if (members.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    l10n.noFamilyMembersYet,
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
}
