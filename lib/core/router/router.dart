import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/local_database.dart';
import '../../demo/demo_mode.dart';
import '../../features/chat/chat_screen.dart';
import '../../features/chat/conversation_info_screen.dart';
import '../../features/chat/image_viewer_screen.dart';
import '../../features/groups/group_editor_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/onboarding/create_family_screen.dart';
import '../../features/onboarding/join_code_screen.dart';
import '../../features/onboarding/join_family_screen.dart';
import '../../features/onboarding/welcome_screen.dart';
import '../../features/settings/edit_profile_screen.dart';
import '../../features/settings/hub_screen.dart';
import '../../services/discovery_service.dart';
import '../providers.dart';
import 'routes.dart';

/// Notifies the router when the device joins or leaves a family.
class _SettingsListenable extends ChangeNotifier {
  _SettingsListenable(this._isConfigured) {
    _configured = _isConfigured();
  }

  final bool Function() _isConfigured;
  late bool _configured;
  late final StreamSubscription<DbChange> _subscription;

  void listenTo(LocalDatabase db) {
    _subscription = db.changes.where((c) => c.table == DbTable.kv).listen((_) {
      final configured = _isConfigured();
      if (configured != _configured) {
        _configured = configured;
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final services = ref.watch(appServicesProvider);
  final refresh = _SettingsListenable(() => services.chat.isConfigured)
    ..listenTo(services.db);
  final launchConversation =
      services.notifications.launchTap?.conversationId;

  final router = GoRouter(
    initialLocation: kDemoMode
        ? demoConfig?.route ?? Routes.home
        : launchConversation != null && services.chat.isConfigured
        ? Routes.chat(launchConversation)
        : Routes.home,
    refreshListenable: refresh,
    redirect: (context, state) {
      final configured = services.chat.isConfigured;
      final onboarding = state.matchedLocation.startsWith(Routes.welcome);
      if (!configured && !onboarding) return Routes.welcome;
      if (configured && onboarding) return Routes.home;
      return null;
    },
    routes: [
      GoRoute(
        path: Routes.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: Routes.welcome,
        builder: (context, state) => const WelcomeScreen(),
        routes: [
          GoRoute(
            path: 'create',
            builder: (context, state) => const CreateFamilyScreen(),
          ),
          GoRoute(
            path: 'join',
            builder: (context, state) => const JoinFamilyScreen(),
            routes: [
              GoRoute(
                path: 'code',
                builder: (context, state) =>
                    JoinCodeScreen(hub: state.extra! as DiscoveredHub),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/chat/:id',
        builder: (context, state) =>
            ChatScreen(conversationId: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'info',
            builder: (context, state) => ConversationInfoScreen(
              conversationId: state.pathParameters['id']!,
            ),
          ),
        ],
      ),
      GoRoute(
        path: Routes.newGroup,
        builder: (context, state) => const GroupEditorScreen(),
      ),
      GoRoute(
        path: '/group/:id/edit',
        builder: (context, state) =>
            GroupEditorScreen(conversationId: state.pathParameters['id']),
      ),
      GoRoute(
        path: Routes.profile,
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: Routes.hub,
        builder: (context, state) =>
            HubScreen(firstRun: state.uri.queryParameters['first'] == '1'),
      ),
      GoRoute(
        path: Routes.viewer,
        builder: (context, state) =>
            ImageViewerScreen(path: state.extra! as String),
      ),
    ],
  );

  final taps = services.notifications.taps.listen(
    (tap) => router.go(Routes.chat(tap.conversationId)),
  );
  ref.onDispose(() {
    taps.cancel();
    refresh.dispose();
    router.dispose();
  });
  return router;
});
