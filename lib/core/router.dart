import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/splash/splash_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/chat/presentation/chat_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/settings/presentation/screens/prompt_management_screen.dart';
import '../features/settings/presentation/screens/docs_screen.dart';
import '../features/settings/presentation/screens/customization_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(path: '/chat', builder: (context, state) => const ChatScreen()),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
        routes: [
          GoRoute(
            path: 'prompts',
            builder: (context, state) => const PromptManagementScreen(),
          ),
          GoRoute(path: 'docs', builder: (context, state) => const Docs()),
          GoRoute(
            path: 'customization',
            builder: (context, state) => const CustomizationScreen(),
          ),
        ],
      ),
    ],
  );
});
