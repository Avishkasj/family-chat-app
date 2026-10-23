import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../core/providers.dart';
import '../../core/router/routes.dart';
import '../../core/theme/extension.dart';
import '../../l10n/app_localizations.dart';
import '../../services/app_lock.dart';
import '../../services/chat_service.dart';
import '../lock/app_lock_gate.dart';
import '../../widgets/member_avatar.dart';

const appVersion = '1.0.0';

class SettingsTab extends ConsumerWidget {
  const SettingsTab({super.key});

  Future<void> _erase(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded),
        title: Text(l10n.leaveFamily),
        content: Text(l10n.leaveFamilyConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.colorScheme.error,
              minimumSize: const Size(64, 40),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.erase),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final lock = ref.read(appLockProvider);
    if (lock.enabled && !await lock.authenticate(l10n.eraseReason)) return;
    await ref.read(appServicesProvider).eraseEverything();
    if (context.mounted) await AppRoot.restart(context);
  }

  void _showPrivacy(BuildContext context) {
    final l10n = context.l10n;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.verified_user_outlined),
        title: Text(l10n.privacy),
        content: SingleChildScrollView(child: Text(l10n.privacyBody)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(MaterialLocalizations.of(context).okButtonLabel),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final me = ref.watch(meProvider);
    final myId = ref.watch(myIdProvider);
    final isOwner = ref.watch(isHubOwnerProvider);
    final hub = ref.watch(hubStatusProvider);
    final link = ref.watch(linkStateProvider);
    final notifications = ref.watch(settingProvider(Keys.notifications)) != '0';
    final keepAlive = ref.watch(settingProvider(Keys.keepAlive)) == '1';
    final host = ref.watch(settingProvider(Keys.hubHost));
    final db = ref.read(databaseProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.settings,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 8,
            ),
            leading: MemberAvatar(memberId: myId, radius: 28),
            title: Text(
              me?.displayName ?? '',
              style: context.textTheme.titleMedium,
            ),
            subtitle: Text(l10n.editProfile),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.profile),
          ),
          const Divider(),
          if (isOwner)
            ListTile(
              leading: const Icon(Icons.router_outlined),
              title: Text(l10n.familyHub),
              subtitle: Text(
                hub.running
                    ? '${l10n.hubRunning} · '
                          '${l10n.hubOnlineCount(hub.online.length, hub.memberCount)}'
                    : l10n.hubStopped,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(Routes.hub),
            )
          else
            ListTile(
              leading: const Icon(Icons.router_outlined),
              title: Text(l10n.familyHub),
              subtitle: Text(
                link.isConnected
                    ? l10n.connectedTo(host ?? '')
                    : l10n.offlineStatus,
              ),
              trailing: link.isConnected
                  ? null
                  : TextButton(
                      onPressed: () =>
                          ref.read(chatServiceProvider).reconnectNow(),
                      child: Text(l10n.retry),
                    ),
            ),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_outlined),
            title: Text(l10n.notificationsSetting),
            value: notifications,
            onChanged: (value) {
              db.setBool(Keys.notifications, value);
              if (value) {
                ref.read(appServicesProvider).notifications.requestPermission();
              }
            },
          ),
          if (Platform.isAndroid && !isOwner)
            SwitchListTile(
              secondary: const Icon(Icons.sync_rounded),
              title: Text(l10n.keepConnected),
              subtitle: Text(l10n.keepConnectedHint),
              value: keepAlive,
              onChanged: (value) async {
                db.setBool(Keys.keepAlive, value);
                await ref.read(hubHostProvider).setKeepAlive(value);
              },
            ),
          const Divider(),
          const _AppLockSettings(),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.verified_user_outlined),
            title: Text(l10n.privacy),
            subtitle: Text(l10n.privacySummary),
            onTap: () => _showPrivacy(context),
          ),
          ListTile(
            leading: const Icon(Icons.fingerprint),
            title: Text(l10n.deviceId),
            subtitle: Text(
              myId.substring(0, 16).replaceAllMapped(
                RegExp('.{4}'),
                (m) => '${m[0]} ',
              ),
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('FamNest'),
            subtitle: Text(l10n.version(appVersion)),
          ),
          const Divider(),
          ListTile(
            leading: Icon(
              Icons.delete_forever_outlined,
              color: context.colorScheme.error,
            ),
            title: Text(
              l10n.leaveFamily,
              style: TextStyle(color: context.colorScheme.error),
            ),
            onTap: () => _erase(context, ref),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}


class _AppLockSettings extends ConsumerWidget {
  const _AppLockSettings();

  String _timeoutLabel(AppLocalizations l10n, LockTimeout timeout) =>
      switch (timeout) {
        LockTimeout.immediately => l10n.lockImmediately,
        LockTimeout.oneMinute => l10n.lockAfterOneMinute,
        LockTimeout.fifteenMinutes => l10n.lockAfterFifteenMinutes,
      };

  Future<void> _chooseTimeout(BuildContext context, AppLock lock) async {
    final l10n = context.l10n;
    final choice = await showDialog<LockTimeout>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.lockWhen),
        children: [
          RadioGroup<LockTimeout>(
            groupValue: lock.timeout,
            onChanged: (value) => Navigator.pop(context, value),
            child: Column(
              children: [
                for (final timeout in LockTimeout.values)
                  RadioListTile<LockTimeout>(
                    value: timeout,
                    title: Text(_timeoutLabel(l10n, timeout)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (choice != null) lock.timeout = choice;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final lock = ref.watch(appLockProvider);
    // Rebuild when the lock settings change.
    ref.watch(settingProvider(Keys.appLock));
    ref.watch(settingProvider(Keys.appLockTimeout));
    final method = ref.watch(lockMethodProvider).value;
    final available = method != null && method != LockMethod.none;
    final label = method == null ? '' : lockMethodLabel(l10n, method);

    return Column(
      children: [
        SwitchListTile(
          secondary: Icon(
            method == null ? Icons.lock_outline : lockMethodIcon(method),
          ),
          title: Text(l10n.appLock),
          subtitle: Text(
            available ? l10n.appLockSubtitle(label) : l10n.appLockUnavailable,
          ),
          value: lock.enabled,
          onChanged: !available
              ? null
              : (value) async {
                  if (value) {
                    final ok = await lock.enable(l10n.enableLockReason);
                    if (!ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.appLockNotEnabled)),
                      );
                    }
                  } else if (await lock.authenticate(l10n.disableLockReason)) {
                    lock.disable();
                  }
                },
        ),
        if (lock.enabled)
          ListTile(
            leading: const Icon(Icons.timer_outlined),
            title: Text(l10n.lockWhen),
            subtitle: Text(_timeoutLabel(l10n, lock.timeout)),
            onTap: () => _chooseTimeout(context, lock),
          ),
      ],
    );
  }
}
