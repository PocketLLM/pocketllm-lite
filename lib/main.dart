import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/storage_service.dart';
import 'providers/settings_provider.dart';
import 'theme/app_theme.dart';
import 'router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  final storageService = StorageService();
  await storageService.init();

  runApp(
    ProviderScope(
      overrides: [
        // We can override storage service here if we want to mock it or provide the initialized instance
        // but we made it stateless mostly, except init.
        // A better pattern is to have a provider for the service that returns the initialized instance.
        // For now, the provider just returns new StorageService(), which is fine as it uses static/singleton Hive box.
      ],
      child: const PocketLLMLiteApp(),
    ),
  );
}

class PocketLLMLiteApp extends ConsumerWidget {
  const PocketLLMLiteApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);

    return settingsAsync.when(
      data: (settings) {
        return MaterialApp.router(
          title: 'Pocket LLM Lite',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: settings.themeMode,
          routerConfig: router,
          debugShowCheckedModeBanner: false,
          builder: (context, child) {
            // Global text scaling
            return MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(settings.fontSizeScale)),
              child: child!,
            );
          },
        );
      },
      loading:
          () => const MaterialApp(
            home: Scaffold(body: Center(child: CircularProgressIndicator())),
          ),
      error:
          (e, st) => MaterialApp(
            home: Scaffold(body: Center(child: Text('Error: $e'))),
          ),
    );
  }
}
