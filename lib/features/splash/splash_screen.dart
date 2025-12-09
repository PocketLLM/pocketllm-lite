import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkFirstLaunch();
  }

  Future<void> _checkFirstLaunch() async {
    await Future.delayed(const Duration(seconds: 2)); // Fake loading/animation
    final storage = ref.read(storageServiceProvider);
    final isFirstLaunch = storage.getSetting(
      AppConstants.isFirstLaunchKey,
      defaultValue: true,
    );

    if (mounted) {
      if (isFirstLaunch) {
        context.go('/onboarding');
      } else {
        context.go('/chat');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child:
            CircularProgressIndicator(), // Replace with proper logo/animation later
      ),
    );
  }
}
