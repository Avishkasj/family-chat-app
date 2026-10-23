import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:network_info_plus/network_info_plus.dart';

import '../../core/providers.dart';
import '../../core/theme/extension.dart';
import '../../data/models.dart';
import '../../services/chat_service.dart';
import '../../shared/crypto.dart';
import '../../widgets/text_prompt_dialog.dart';
import '../home/family_tab.dart';

final _wifiIpProvider = FutureProvider.autoDispose<String?>((ref) async {
  try {
    return await NetworkInfo().getWifiIP();
  } catch (_) {
    return null;
  }
});

/// Management of the family hub hosted on this device.
class HubScreen extends ConsumerStatefulWidget {
  const HubScreen({super.key, this.firstRun = false});

  final bool firstRun;

  @override
  ConsumerState<HubScreen> createState() => _HubScreenState();
}

class _HubScreenState extends ConsumerState<HubScreen> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.somethingWentWrong('$e'))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String title, String body, String action) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(64, 40)),
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _rename(String current) async {
    final name = await showTextPrompt(
      context,
      title: context.l10n.renameFamily,
      actionLabel: context.l10n.save,
      initialValue: current,
      maxLength: 40,
      capitalization: TextCapitalization.words,
    );
    if (name == null || name.isEmpty) return;
    await _run(() => ref.read(hubHostProvider).renameFamily(name));
  }

  Future<void> _removeMember(Member member) async {
    final l10n = context.l10n;
    if (!await _confirm(
      l10n.removeMember,
      l10n.removeMemberConfirm(member.displayName),
      l10n.removeMember,
    )) {
      return;
    }
    await _run(() => ref.read(hubHostProvider).removeMember(member.id));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = context.colorScheme;
    final status = ref.watch(hubStatusProvider);
    final host = ref.read(hubHostProvider);
    final ip = ref.watch(_wifiIpProvider).value;
    final members = ref.watch(familyMembersProvider);
    final code = formatInviteCode(status.inviteCode);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.familyHub)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          if (_busy) const LinearProgressIndicator(),
          if (widget.firstRun)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.inviteTitle, style: context.textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(l10n.inviteBody),
                ],
              ),
            ),
          Card(
            margin: const EdgeInsets.all(16),
            color: scheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    l10n.inviteCode,
                    style: context.textTheme.labelLarge?.copyWith(
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    status.running ? code : '—',
                    textAlign: TextAlign.center,
                    style: context.textTheme.headlineSmall?.copyWith(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (status.running)
                    TextButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: code));
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(l10n.copied)));
                      },
                      icon: const Icon(Icons.copy_rounded),
                      label: Text(l10n.copy),
                    ),
                  if (ip != null)
                    Text(
                      l10n.hubAddress('$ip:${status.port}'),
                      style: context.textTheme.bodySmall?.copyWith(
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                ],
              ),
            ),
          ),
          ListTile(
            leading: Icon(
              status.running ? Icons.check_circle : Icons.pause_circle,
              color: status.running ? Colors.green : scheme.error,
            ),
            title: Text(status.running ? l10n.hubRunning : l10n.hubStopped),
            subtitle: status.running
                ? Text(
                    l10n.hubOnlineCount(
                      status.online.length,
                      status.memberCount,
                    ),
                  )
                : null,
            trailing: status.running
                ? TextButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            if (await _confirm(
                              l10n.stopHub,
                              l10n.stopHubConfirm,
                              l10n.stopHub,
                            )) {
                              ref
                                  .read(databaseProvider)
                                  .setBool(Keys.hubPaused, true);
                              await _run(host.stop);
                            }
                          },
                    child: Text(l10n.stopHub),
                  )
                : FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(64, 40),
                    ),
                    onPressed: _busy
                        ? null
                        : () {
                            ref
                                .read(databaseProvider)
                                .setBool(Keys.hubPaused, false);
                            _run(host.start);
                          },
                    child: Text(l10n.startHub),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Text(
              Platform.isAndroid ? l10n.hubTips : l10n.hubIosNote,
              style: context.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          if (Platform.isAndroid)
            ListTile(
              leading: const Icon(Icons.battery_saver_outlined),
              title: Text(l10n.batteryOptimization),
              subtitle: Text(l10n.batteryOptimizationHint),
              onTap: () =>
                  FlutterForegroundTask.openIgnoreBatteryOptimizationSettings(),
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: Text(l10n.renameFamily),
            subtitle: Text(ref.watch(familyNameProvider)),
            enabled: status.running && !_busy,
            onTap: () => _rename(ref.read(familyNameProvider)),
          ),
          ListTile(
            leading: const Icon(Icons.key_rounded),
            title: Text(l10n.rotateCode),
            subtitle: Text(l10n.rotateCodeHint),
            enabled: status.running && !_busy,
            onTap: () async {
              if (await _confirm(
                l10n.rotateCode,
                l10n.rotateCodeConfirm,
                l10n.rotateCode,
              )) {
                await _run(() async {
                  await host.rotateInviteCode();
                });
              }
            },
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Text(
              l10n.membersCount(members.length + 1),
              style: context.textTheme.labelLarge?.copyWith(
                color: scheme.primary,
              ),
            ),
          ),
          for (final member in members)
            FamilyMemberTile(
              member: member,
              trailing: IconButton(
                tooltip: l10n.removeMember,
                icon: Icon(Icons.person_remove_outlined, color: scheme.error),
                onPressed: status.running && !_busy
                    ? () => _removeMember(member)
                    : null,
              ),
            ),
          if (widget.firstRun)
            Padding(
              padding: const EdgeInsets.all(20),
              child: FilledButton(
                onPressed: () => context.pop(),
                child: Text(l10n.continueAction),
              ),
            ),
        ],
      ),
    );
  }
}
