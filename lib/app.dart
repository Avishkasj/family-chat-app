import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_services.dart';
import 'core/providers.dart';
import 'core/router/router.dart';
import 'core/theme/app_theme.dart';
import 'features/lock/app_lock_gate.dart';
import 'features/splash/splash_view.dart';
import 'flavors.dart';
import 'widgets/adaptive_layout.dart';
import 'l10n/app_localizations.dart';

/// Creates the app's services, and recreates them after the user erases all
/// data so the app starts fresh without a restart.
class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  static Future<void> restart(BuildContext context) =>
      context.findAncestorStateOfType<_AppRootState>()!._restart();

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> with WidgetsBindingObserver {
  AppServices? _services;
  Object? _error;
  Key _scopeKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _services?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final services = await AppServices.create();
      if (!mounted) return;
      setState(() {
        _services = services;
        _error = null;
        _scopeKey = UniqueKey();
      });
    } catch (e, s) {
      debugPrint('Startup failed: $e\n$s');
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _restart() async {
    _services?.dispose();
    setState(() => _services = null);
    await _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final services = _services;
    if (services == null) return;
    services.appLock.onLifecycle(state);
    final chat = services.chat;
    chat.appInForeground = state == AppLifecycleState.resumed;
    if (state != AppLifecycleState.resumed) return;
    if (chat.isHubOwner) {
      unawaited(
        services.hubHost
            .ensureRunning()
            .catchError((Object e) => debugPrint('Hub restart failed: $e'))
            .whenComplete(chat.reconnectNow),
      );
    } else {
      chat.reconnectNow();
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = _services;
    final Widget child = services == null
        ? MaterialApp(
            key: const ValueKey('splash'),
            title: F.title,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            debugShowCheckedModeBanner: false,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SplashView(error: _error),
          )
        : ProviderScope(
            key: _scopeKey,
            overrides: [appServicesProvider.overrideWithValue(services)],
            child: const App(),
          );
    // Cross-fade from the splash into the app.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: splashBackground,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          switchInCurve: Curves.easeOut,
          child: child,
        ),
      ),
    );
  }
}

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: F.title,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) {
        final content = AppLockGate(child: AdaptiveLayout(child: child!));
        return F.appFlavor == Flavor.dev && kDebugMode
            ? Banner(
                location: BannerLocation.topStart,
                message: F.name,
                color: Colors.green.withAlpha(150),
                child: content,
              )
            : content;
      },
    );
  }
}
