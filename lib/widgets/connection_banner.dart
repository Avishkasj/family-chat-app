import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import '../core/theme/extension.dart';
import '../services/chat_service.dart';
import '../shared/crypto.dart';
import '../shared/protocol.dart';

/// Shows the state of the link to the family hub when it isn't connected.
class ConnectionBanner extends ConsumerWidget {
  const ConnectionBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final link = ref.watch(linkStateProvider);
    final l10n = context.l10n;
    final scheme = context.colorScheme;

    final (String text, IconData icon, Widget? action, bool error) =
        switch (link.status) {
          LinkStatus.connected || LinkStatus.notConfigured => (
            '',
            Icons.check,
            null,
            false,
          ),
          LinkStatus.connecting => (l10n.connecting, Icons.sync, null, false),
          LinkStatus.searching => (
            l10n.searchingHub,
            Icons.wifi_find,
            null,
            false,
          ),
          LinkStatus.offline => (
            l10n.offline,
            Icons.wifi_off_rounded,
            TextButton(
              onPressed: () => ref.read(chatServiceProvider).reconnectNow(),
              child: Text(l10n.retry),
            ),
            false,
          ),
          LinkStatus.authFailed => link.reason == AuthFailure.removed
              ? (l10n.removedBanner, Icons.block, null, true)
              : (
                  l10n.inviteCodeChanged,
                  Icons.key_rounded,
                  TextButton(
                    onPressed: () => showNewInviteCodeDialog(context, ref),
                    child: Text(l10n.enterNewCode),
                  ),
                  true,
                ),
        };

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      child: text.isEmpty
          ? const SizedBox(width: double.infinity)
          : Material(
              color: error ? scheme.errorContainer : scheme.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                child: Row(
                  children: [
                    Icon(
                      icon,
                      size: 20,
                      color: error
                          ? scheme.onErrorContainer
                          : scheme.onSecondaryContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        text,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: error
                              ? scheme.onErrorContainer
                              : scheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                    ?action,
                  ],
                ),
              ),
            ),
    );
  }
}

Future<void> showNewInviteCodeDialog(BuildContext context, WidgetRef ref) async {
  final code = await showDialog<String>(
    context: context,
    builder: (context) => const _InviteCodeDialog(),
  );
  if (code != null) {
    await ref.read(chatServiceProvider).updateInviteCode(code);
  }
}

class _InviteCodeDialog extends StatefulWidget {
  const _InviteCodeDialog();

  @override
  State<_InviteCodeDialog> createState() => _InviteCodeDialogState();
}

class _InviteCodeDialogState extends State<_InviteCodeDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!isValidInviteCode(_controller.text)) {
      setState(() => _error = context.l10n.inviteCodeInvalid);
      return;
    }
    Navigator.of(context).pop(normalizeInviteCode(_controller.text));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.inviteCode),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.characters,
        decoration: InputDecoration(
          hintText: 'ABCD-EFGH-JKMN-PQRS',
          errorText: _error,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.connect)),
      ],
    );
  }
}
