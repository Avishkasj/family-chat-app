import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/router/routes.dart';
import '../../core/theme/extension.dart';
import '../../widgets/member_avatar.dart';

/// Creates a new group, or edits the name and members of an existing one.
class GroupEditorScreen extends ConsumerStatefulWidget {
  const GroupEditorScreen({super.key, this.conversationId});

  final String? conversationId;

  @override
  ConsumerState<GroupEditorScreen> createState() => _GroupEditorScreenState();
}

class _GroupEditorScreenState extends ConsumerState<GroupEditorScreen> {
  final _name = TextEditingController();
  final Set<String> _selected = {};
  bool _busy = false;

  bool get _editing => widget.conversationId != null;

  @override
  void initState() {
    super.initState();
    final id = widget.conversationId;
    if (id != null) {
      final conversation = ref.read(conversationProvider(id));
      if (conversation != null) {
        _name.text = conversation.name;
        _selected.addAll(conversation.members);
      }
    }
    _selected.remove(ref.read(myIdProvider));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final name = _name.text.trim();
    if (name.isEmpty) {
      _snack(l10n.groupNameRequired);
      return;
    }
    if (_selected.isEmpty) {
      _snack(l10n.selectAtLeastOne);
      return;
    }
    setState(() => _busy = true);
    final chat = ref.read(chatServiceProvider);
    try {
      if (_editing) {
        await chat.updateGroup(widget.conversationId!, name, {
          ..._selected,
          chat.myId,
        });
        if (mounted) context.pop();
      } else {
        final id = await chat.createGroup(name, _selected);
        if (mounted) context.pushReplacement(Routes.chat(id));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        _snack(l10n.notConnectedAction);
      }
    }
  }

  void _snack(String text) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final members = ref.watch(familyMembersProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? l10n.editGroup : l10n.newGroup),
        actions: [
          TextButton(
            onPressed: _busy ? null : _save,
            child: Text(_editing ? l10n.save : l10n.createGroup),
          ),
        ],
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: TextField(
              controller: _name,
              autofocus: !_editing,
              maxLength: 50,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l10n.groupName,
                hintText: l10n.groupNameHint,
                prefixIcon: const Icon(Icons.groups_outlined),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              l10n.chooseMembers,
              style: context.textTheme.labelLarge?.copyWith(
                color: context.colorScheme.primary,
              ),
            ),
          ),
          for (final member in members)
            CheckboxListTile(
              secondary: MemberAvatar(memberId: member.id),
              title: Text(member.displayName),
              value: _selected.contains(member.id),
              onChanged: (value) => setState(() {
                if (value ?? false) {
                  _selected.add(member.id);
                } else {
                  _selected.remove(member.id);
                }
              }),
            ),
          if (members.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(l10n.noFamilyMembersYet, textAlign: TextAlign.center),
            ),
        ],
      ),
    );
  }
}
