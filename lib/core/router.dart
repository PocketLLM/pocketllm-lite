import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/splash/splash_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/chat/presentation/chat_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/settings/presentation/screens/prompt_management_screen.dart';
import '../features/settings/presentation/screens/template_management_screen.dart';
import '../features/settings/presentation/screens/docs_screen.dart';
import '../features/settings/presentation/screens/customization_screen.dart';
import '../features/settings/presentation/screens/activity_log_screen.dart';
import '../features/settings/presentation/screens/usage_statistics_screen.dart';
import '../features/chat/presentation/screens/starred_messages_screen.dart';
import '../features/media/presentation/screens/media_gallery_screen.dart';
import '../features/tags/presentation/screens/tag_management_screen.dart';
import '../features/profile/presentation/screens/profile_screen.dart';
import '../features/settings/presentation/screens/system_prompt_details_screen.dart';
import '../features/error_log/presentation/error_log_screen.dart';
import '../features/model_browser/presentation/model_browser_screen.dart';
import '../features/model_browser/presentation/model_detail_screen.dart';
import '../features/model_browser/presentation/model_catalog_screen.dart';
import '../features/model_browser/presentation/model_store_screen.dart';
import '../features/model_browser/presentation/local_model_help_screen.dart';
import '../features/rag/presentation/document_manager_screen.dart';
import '../features/settings/presentation/screens/benchmark_screen.dart';
import '../features/chat/presentation/screens/persona_management_screen.dart';
import '../features/chat/presentation/screens/skill_management_screen.dart';
import '../features/chat/presentation/screens/skill_details_screen.dart';
import '../features/settings/presentation/screens/privacy_network_screen.dart';
import '../features/chat/presentation/screens/model_comparison_screen.dart';
import '../features/profile/presentation/screens/memory_inspector_screen.dart';
import '../features/media/presentation/screens/audio_transcription_screen.dart';
import '../features/settings/presentation/screens/prompt_lab_screen.dart';
import 'navigation.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
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
        path: '/model-browser',
        builder: (context, state) => const ModelBrowserScreen(),
      ),
      GoRoute(
        path: '/model-detail',
        builder: (context, state) =>
            ModelDetailScreen(modelId: state.extra as String),
      ),
      GoRoute(
        path: '/document-manager',
        builder: (context, state) => const DocumentManagerScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
        routes: [
          GoRoute(
            path: 'model-catalog',
            builder: (context, state) => ModelStoreScreen(
              initialQuery: state.uri.queryParameters['query'] ?? '',
            ),
          ),
          GoRoute(
            path: 'local-models',
            builder: (context, state) => const ModelCatalogScreen(),
          ),
          GoRoute(
            path: 'model-help',
            builder: (context, state) => const LocalModelHelpScreen(),
          ),
          GoRoute(
            path: 'error-log',
            builder: (context, state) => const ErrorLogScreen(),
          ),
          GoRoute(
            path: 'prompts',
            builder: (context, state) => const PromptManagementScreen(),
            routes: [
              GoRoute(
                path: 'details/:id',
                builder: (context, state) {
                  final id = state.pathParameters['id'];
                  return SystemPromptDetailsScreen(promptId: id);
                },
              ),
            ],
          ),
          GoRoute(
            path: 'templates',
            builder: (context, state) => const TemplateManagementScreen(),
          ),
          GoRoute(path: 'docs', builder: (context, state) => const Docs()),
          GoRoute(
            path: 'customization',
            builder: (context, state) => const CustomizationScreen(),
          ),
          GoRoute(
            path: 'activity-log',
            builder: (context, state) => const ActivityLogScreen(),
          ),
          GoRoute(
            path: 'statistics',
            builder: (context, state) => const UsageStatisticsScreen(),
          ),
          GoRoute(
            path: 'starred-messages',
            builder: (context, state) => const StarredMessagesScreen(),
          ),
          GoRoute(
            path: 'media-gallery',
            builder: (context, state) => const MediaGalleryScreen(),
          ),
          GoRoute(
            path: 'tags',
            builder: (context, state) => const TagManagementScreen(),
          ),
          GoRoute(
            path: 'profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: 'benchmark',
            builder: (context, state) => const BenchmarkScreen(),
          ),
          GoRoute(
            path: 'personas',
            builder: (context, state) => const PersonaManagementScreen(),
          ),
          GoRoute(
            path: 'privacy-network',
            builder: (context, state) => const PrivacyNetworkScreen(),
          ),
          GoRoute(
            path: 'model-comparison',
            builder: (context, state) => const ModelComparisonScreen(),
          ),
          GoRoute(
            path: 'memory-inspector',
            builder: (context, state) => const MemoryInspectorScreen(),
          ),
          GoRoute(
            path: 'audio-transcription',
            builder: (context, state) => const AudioTranscriptionScreen(),
          ),
          GoRoute(
            path: 'prompt-lab',
            builder: (context, state) => const PromptLabScreen(),
          ),
          GoRoute(
            path: 'skills',
            builder: (context, state) => const SkillManagementScreen(),
            routes: [
              GoRoute(
                path: 'details/:id',
                builder: (context, state) {
                  final id = state.pathParameters['id'] ?? '';
                  return SkillDetailsScreen(skillId: id);
                },
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
