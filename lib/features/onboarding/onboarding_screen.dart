import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_m3shapes/flutter_m3shapes.dart';
import '../../core/constants/app_constants.dart';
import '../../core/providers.dart';
import '../../core/theme/app_motion.dart';
import 'widgets/offline_notification_popup.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: AppMotion.durationXL,
      vsync: this,
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: AppMotion.curveEnter),
    );
    _scaleAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: AppMotion.curveOvershoot),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: ScaleTransition(
            scale: _scaleAnim,
            child: Column(
              children: [
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (index) =>
                        setState(() => _currentPage = index),
                    children: [
                      _buildPage(
                        title: 'Welcome to PocketLLM',
                        description:
                            'A local-first assistant with clear network controls.\n\n'
                            'Use supported on-device Cactus models or an Ollama endpoint you choose. Optional online features stay under your control.',
                        icon: Icons.security_outlined,
                        shape: Shapes.gem,
                        containerColor: theme.colorScheme.primaryContainer,
                        iconColor: theme.colorScheme.onPrimaryContainer,
                      ),
                      _buildPage(
                        title: 'Setup & Chat',
                        description:
                            'Choose a verified on-device model, or connect to an Ollama server on a trusted computer. Android/Termux builds are experimental and not officially supported by Ollama.\n\n'
                            'Customize your experience with different models, '
                            'system prompts, and themes.',
                        icon: Icons.chat_bubble_outline_rounded,
                        shape: Shapes.flower,
                        containerColor: theme.colorScheme.tertiaryContainer,
                        iconColor: theme.colorScheme.onTertiaryContainer,
                      ),
                      _buildPrivacyPreferencesPage(),
                    ],
                  ),
                ),
                // Bottom navigation: dots + button
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Page indicators
                      Row(
                        children: List.generate(
                          3,
                          (index) => AnimatedContainer(
                            duration: AppMotion.durationMD,
                            curve: AppMotion.curveStandard,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            height: 8,
                            width: _currentPage == index ? 32 : 8,
                            decoration: BoxDecoration(
                              color: _currentPage == index
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outlineVariant,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                      // Navigation button
                      if (_currentPage == 2)
                        FilledButton.icon(
                          onPressed: _finishOnboarding,
                          icon: const Icon(Icons.arrow_forward_rounded),
                          label: const Text('Get Started'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 14,
                            ),
                          ),
                        )
                      else
                        FilledButton.tonal(
                          onPressed: () {
                            _pageController.nextPage(
                              duration: AppMotion.durationLG,
                              curve: AppMotion.curveStandard,
                            );
                          },
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 14,
                            ),
                          ),
                          child: const Text('Next'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPage({
    required String title,
    required String description,
    required IconData icon,
    required Shapes shape,
    required Color containerColor,
    required Color iconColor,
  }) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Expressive shape container for the icon
          M3Container(
            shape,
            width: 140,
            height: 140,
            color: containerColor,
            child: Center(child: Icon(icon, size: 64, color: iconColor)),
          ),
          const SizedBox(height: 48),
          Text(
            title,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            description,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyPreferencesPage() {
    final theme = Theme.of(context);
    final storage = ref.watch(storageServiceProvider);

    final autoUpdateVal = storage.getSetting(
      AppConstants.autoUpdateCheckKey,
      defaultValue: false,
    );
    final autoUpdate = autoUpdateVal is bool ? autoUpdateVal : false;

    final onlineModelsVal = storage.getSetting(
      AppConstants.onlineModelBrowsingKey,
      defaultValue: true,
    );
    final onlineModels = onlineModelsVal is bool ? onlineModelsVal : true;

    final strictOfflineVal = storage.getSetting(
      AppConstants.strictOfflineModeKey,
      defaultValue: false,
    );
    final strictOffline = strictOfflineVal is bool ? strictOfflineVal : false;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 600 ||
            MediaQuery.textScalerOf(context).scale(16) > 19.2;

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: 24,
            vertical: compact ? 8 : 16,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: compact ? 40 : 56,
                  color: theme.colorScheme.primary,
                ),
                SizedBox(height: compact ? 8 : 16),
                Text(
                  'Privacy & Connection Controls',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: compact ? 4 : 8),
                Text(
                  'Configure network permissions according to your privacy standards. All settings can be adjusted later.',
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: compact ? 12 : 20),
                Card(
                  child: Column(
                    children: [
                      CheckboxListTile(
                        title: const Text(
                          'Check GitHub for updates automatically?',
                        ),
                        subtitle: const Text(
                          'Connects to api.github.com for new releases. (Default: Off)',
                        ),
                        value: autoUpdate,
                        onChanged: (val) async {
                          await storage.saveSetting(
                            AppConstants.autoUpdateCheckKey,
                            val ?? false,
                          );
                          setState(() {});
                        },
                      ),
                      const Divider(height: 1),
                      CheckboxListTile(
                        title: const Text(
                          'Allow optional online model browsing?',
                        ),
                        subtitle: const Text(
                          'Enables searching Hugging Face for downloadable GGUF models.',
                        ),
                        value: onlineModels,
                        onChanged: (val) async {
                          await storage.saveSetting(
                            AppConstants.onlineModelBrowsingKey,
                            val ?? true,
                          );
                          setState(() {});
                        },
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text('Enable Strict Offline Mode'),
                        subtitle: const Text(
                          'Blocks all non-loopback network calls at application level.',
                        ),
                        value: strictOffline,
                        onChanged: (val) async {
                          await storage.saveSetting(
                            AppConstants.strictOfflineModeKey,
                            val,
                          );
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _finishOnboarding() async {
    final storage = ref.read(storageServiceProvider);
    await storage.saveSetting(AppConstants.isFirstLaunchKey, false);

    if (mounted) {
      final shouldGoToDocs = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const OfflineNotificationPopup();
        },
      );

      if (mounted) {
        if (shouldGoToDocs == true) {
          context.go('/settings/docs');
        } else {
          context.go('/chat');
        }
      }
    }
  }
}
