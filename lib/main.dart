import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/router.dart';
import 'core/providers.dart';
import 'core/theme/theme_provider.dart';
import 'core/widgets/update_dialog.dart';
import 'services/storage_service.dart';
import 'services/ad_service.dart';
import 'services/update_service.dart';

import 'package:flutter_native_splash/flutter_native_splash.dart';

// Global navigator key for showing dialogs from anywhere
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  final storageService = StorageService();
  await storageService.init();

  // Initialize AdMob
  await AdService.initialize();

  // Preload all rewarded ads immediately
  final adService = AdService();
  adService.preloadRewardedAd();
  adService.preloadDeletionRewardedAd();
  adService.preloadPromptEnhancementRewardedAd();
  adService.preloadChatCreationRewardedAd();

  // Set up periodic preloading to ensure ads are always ready
  // This runs every 2 minutes to check and reload ads if needed
  Future.delayed(const Duration(minutes: 2), () {
    _periodicAdPreload(adService);
  });

  FlutterNativeSplash.remove();

  runApp(
    ProviderScope(
      overrides: [storageServiceProvider.overrideWithValue(storageService)],
      child: const PocketLLMApp(),
    ),
  );

  // Check for updates after app is initialized (delayed to avoid blocking UI)
  Future.delayed(const Duration(seconds: 3), () {
    _checkForUpdates();
  });
}

// Check for updates from GitHub releases
Future<void> _checkForUpdates() async {
  try {
    final updateService = UpdateService();
    final result = await updateService.checkForUpdates();

    if (result.updateAvailable && result.release != null) {
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        UpdateDialog.show(context, result.release!);
      }
    }
  } catch (e) {
    // Silently fail - don't interrupt user experience for update check failures
    debugPrint('Update check failed: $e');
  }
}

// Periodic ad preloading to ensure ads are always ready
void _periodicAdPreload(AdService adService) {
  // Preload any ads that aren't currently loaded
  if (!adService.isRewardedLoaded) {
    adService.preloadRewardedAd();
  }
  if (!adService.isDeletionRewardedLoaded) {
    adService.preloadDeletionRewardedAd();
  }
  if (!adService.isPromptEnhancementRewardedLoaded) {
    adService.preloadPromptEnhancementRewardedAd();
  }
  if (!adService.isChatCreationRewardedLoaded) {
    adService.preloadChatCreationRewardedAd();
  }

  // Schedule next check in 2 minutes
  Future.delayed(const Duration(minutes: 2), () {
    _periodicAdPreload(adService);
  });
}

class PocketLLMApp extends ConsumerWidget {
  const PocketLLMApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeProvider);

    return MaterialApp.router(
      key: navigatorKey,
      title: 'Pocket LLM Lite',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
