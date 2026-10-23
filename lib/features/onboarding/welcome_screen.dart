import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/extension.dart';
import '../../widgets/app_logo.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = context.colorScheme;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(child: AppLogo(size: 104)),
                      const SizedBox(height: 24),
                      Text(
                        l10n.welcomeTitle,
                        textAlign: TextAlign.center,
                        style: context.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.welcomeBody,
                        textAlign: TextAlign.center,
                        style: context.textTheme.bodyLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _Point(Icons.lock_rounded, l10n.privacyPoint1),
                      _Point(Icons.wifi_rounded, l10n.privacyPoint2),
                      _Point(Icons.phone_android_rounded, l10n.privacyPoint3),
                      const SizedBox(height: 32),
                      FilledButton.icon(
                        onPressed: () => context.push(Routes.joinFamily),
                        icon: const Icon(Icons.group_add_rounded),
                        label: Text(l10n.joinFamily),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.joinFamilyHint,
                        textAlign: TextAlign.center,
                        style: context.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () => context.push(Routes.createFamily),
                        icon: const Icon(Icons.home_rounded),
                        label: Text(l10n.createFamily),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.createFamilyHint,
                        textAlign: TextAlign.center,
                        style: context.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: Row(
        children: [
          Icon(icon, size: 20, color: context.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: context.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
