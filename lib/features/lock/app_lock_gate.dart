import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/extension.dart';
import '../../l10n/app_localizations.dart';
import '../../services/app_lock.dart';
import '../../widgets/app_logo.dart';

String lockMethodLabel(AppLocalizations l10n, LockMethod method) =>
    switch (method) {
      LockMethod.faceId => l10n.faceId,
      LockMethod.touchId => l10n.touchId,
      LockMethod.face => l10n.faceUnlock,
      LockMethod.fingerprint => l10n.fingerprint,
      LockMethod.biometrics => l10n.biometrics,
      LockMethod.passcode || LockMethod.none => l10n.devicePasscode,
    };

IconData lockMethodIcon(LockMethod method) => switch (method) {
  LockMethod.faceId || LockMethod.face => Icons.face_unlock_outlined,
  LockMethod.touchId ||
  LockMethod.fingerprint ||
  LockMethod.biometrics => Icons.fingerprint,
  LockMethod.passcode || LockMethod.none => Icons.pin_outlined,
};

/// The device's unlock method (cached per app session).
final lockMethodProvider = FutureProvider<LockMethod>(
  (ref) => ref.watch(appLockProvider).availableMethod(),
);

/// Covers the app with the lock screen while locked, and with a plain
/// privacy screen while it's in the app switcher.
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate> {
  late final AppLock _lock = ref.read(appLockProvider);
  bool _prompted = false;

  @override
  void initState() {
    super.initState();
    _lock.addListener(_changed);
    _changed();
  }

  @override
  void dispose() {
    _lock.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    final showing = _lock.locked && !_lock.obscured;
    if (!showing) {
      _prompted = false;
    } else if (!_prompted &&
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      // Prompt automatically once each time the lock screen appears. iOS
      // rejects Face ID until the app is really in the foreground, so wait
      // for "resumed" (AppLock notifies again when it arrives).
      _prompted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
    }
    setState(() {});
  }

  Future<void> _unlock() async {
    if (!mounted) return;
    await _lock.unlock(context.l10n.unlockReason);
  }

  @override
  Widget build(BuildContext context) {
    final cover = _lock.locked || _lock.obscured;
    return Stack(
      children: [
        // Keep the app alive underneath but hidden from screen readers.
        ExcludeSemantics(excluding: cover, child: widget.child),
        if (_lock.locked)
          _LockScreen(onUnlock: _unlock)
        else if (_lock.obscured)
          const _PrivacyCover(),
      ],
    );
  }
}

class _PrivacyCover extends StatelessWidget {
  const _PrivacyCover();

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Positioned.fill(
      child: ColoredBox(
        color: scheme.surface,
        child: const Center(child: AppLogo(size: 88)),
      ),
    );
  }
}

class _LockScreen extends ConsumerWidget {
  const _LockScreen({required this.onUnlock});

  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final scheme = context.colorScheme;
    final method =
        ref.watch(lockMethodProvider).value ?? LockMethod.passcode;
    return Positioned.fill(
      child: Material(
        color: scheme.surface,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                const Spacer(),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const AppLogo(size: 96),
                    Positioned(
                      right: -6,
                      bottom: -6,
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: scheme.surface,
                        child: Icon(Icons.lock_rounded, color: scheme.primary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.lockedTitle,
                  style: context.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.lockedBody,
                  textAlign: TextAlign.center,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: onUnlock,
                  icon: Icon(lockMethodIcon(method)),
                  label: Text(
                    l10n.unlockWith(lockMethodLabel(l10n, method)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
