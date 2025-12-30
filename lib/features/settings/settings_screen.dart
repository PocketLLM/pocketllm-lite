import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../../../core/constants/legal_constants.dart';

import '../../core/constants/app_constants.dart';
import '../../core/providers.dart';
import '../../core/theme/theme_provider.dart';
import '../../services/ad_service.dart';
import '../../services/usage_limits_provider.dart';
import '../chat/presentation/providers/models_provider.dart';
import '../chat/presentation/providers/prompt_enhancer_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _urlController;
  String _version = 'Loading...';
  bool _isConnecting = false;
  bool? _isConnected;
  bool _isRefreshingModels = false; // Add this to track refresh state

  // Banner Ad
  final AdService _adService = AdService();
  bool _isBannerLoaded = false;
  BannerAd? _bannerAd;
  int _bannerRetryCount = 0;
  static const int _maxBannerRetries = 5;

  @override
  void initState() {
    super.initState();
    final storage = ref.read(storageServiceProvider);
    final url = storage.getSetting(
      AppConstants.ollamaBaseUrlKey,
      defaultValue: AppConstants.defaultOllamaBaseUrl,
    );
    _urlController = TextEditingController(text: url);
    _loadVersion();
    _checkConnection();

    // Add a small delay to ensure the widget is built before loading the banner
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBannerAd();
    });

    // Automatically refresh usage limits and models when settings page is opened
    // Use Future.delayed to avoid modifying providers during widget build
    Future.delayed(Duration.zero, () {
      _refreshUsageLimits();
      _refreshModels();
    });
  }

  // Add this method to refresh usage limits
  void _refreshUsageLimits() {
    ref.read(usageLimitsProvider.notifier).reload();
  }

  // Add this method to refresh models
  Future<void> _refreshModels() async {
    setState(() {
      _isRefreshingModels = true;
    });

    // Refresh the models provider
    ref.invalidate(modelsProvider);

    // Small delay to ensure UI updates
    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      setState(() {
        _isRefreshingModels = false;
      });
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _bannerAd?.dispose();
    super.dispose();
  }

  Future<void> _loadBannerAd() async {
    _bannerAd?.dispose();
    _bannerAd = await _adService.createAndLoadBannerAd(
      onLoaded: () {
        if (mounted) {
          setState(() {
            _isBannerLoaded = true;
            _bannerRetryCount = 0; // Reset retry count on success
          });
        }
      },
      onFailed: (error) {
        if (kDebugMode) {
          // print('Banner ad failed to load: $error');
        }
        if (mounted) {
          setState(() => _isBannerLoaded = false);
          // Retry loading the banner ad after a longer delay with max retries
          if (_bannerRetryCount < _maxBannerRetries) {
            _bannerRetryCount++;
            Future.delayed(const Duration(seconds: 5), () {
              if (mounted && !_isBannerLoaded) {
                _loadBannerAd();
              }
            });
          }
        }
      },
    );
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() => _version = '${info.version} (${info.buildNumber})');
    }
  }

  Future<void> _checkConnection() async {
    setState(() => _isConnecting = true);
    final connected = await ref.read(ollamaServiceProvider).checkConnection();
    if (mounted) {
      setState(() {
        _isConnected = connected;
        _isConnecting = false;
      });
    }
  }

  Future<void> _saveUrl() async {
    final url = _urlController.text.trim();
    if (Uri.tryParse(url) == null) return;

    final storage = ref.read(storageServiceProvider);
    await storage.saveSetting(AppConstants.ollamaBaseUrlKey, url);
    ref.read(ollamaServiceProvider).updateBaseUrl(url);

    // Test again
    await _checkConnection();
    ref.invalidate(modelsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final storage = ref.watch(storageServiceProvider);

    return PopScope(
      onPopInvokedWithResult: (didPop, result) async {
        // Use GoRouter's pop method instead of Navigator.pop to avoid stack issues
        if (GoRouter.of(context).canPop()) {
          context.pop();
        } else {
          // If we can't pop, go to the chat screen directly
          context.go('/chat');
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              HapticFeedback.selectionClick();
              // Use GoRouter's pop method instead of Navigator.pop to avoid stack issues
              if (GoRouter.of(context).canPop()) {
                context.pop();
              } else {
                // If we can't pop, go to the chat screen directly
                context.go('/chat');
              }
            },
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildConnectionSection(theme),
                  const SizedBox(height: 24),
                  _buildPromptSection(theme),
                  const SizedBox(height: 24),
                  _buildModelsSection(theme),
                  const SizedBox(height: 24),
                  _buildPromptEnhancerSection(theme),
                  const SizedBox(height: 24),
                  _buildUsageLimitsSection(theme),
                  const SizedBox(height: 24),
                  _buildStorageSection(theme, storage),
                  const SizedBox(height: 24),
                  _buildAppearanceSection(theme, storage),
                  const SizedBox(height: 24),
                  _buildAboutSection(theme),
                  const SizedBox(height: 60), // Space for banner
                ],
              ),
            ),
            // Banner Ad at bottom
            _buildBannerAd(),
          ],
        ),
      ),
    );
  }

  Widget _buildBannerAd() {
    if (_isBannerLoaded && _bannerAd != null) {
      return SafeArea(
        child: Container(
          alignment: Alignment.center,
          width: double.infinity,
          height: 60,
          child: Stack(
            alignment: Alignment.topRight,
            children: [
              Container(height: 60, child: AdWidget(ad: _bannerAd!)),
              Positioned(
                top: -10,
                right: 0,
                child: Container(
                  padding: EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.refresh, size: 16, color: Colors.white),
                    onPressed: () {
                      _bannerRetryCount = 0; // Reset retry count
                      _loadBannerAd();
                    },
                    padding: EdgeInsets.all(4),
                    constraints: BoxConstraints.tight(Size(20, 20)),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Container(
      height: 60,
      alignment: Alignment.center,
      color: Colors.grey[200],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Ad loading...',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          IconButton(
            icon: Icon(Icons.refresh, size: 16),
            onPressed: () {
              _bannerRetryCount = 0; // Reset retry count
              _loadBannerAd();
            },
            padding: EdgeInsets.all(4),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildConnectionSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Ollama Connection'),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.3,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Status'),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: (_isConnected ?? false)
                          ? Colors.green.withValues(alpha: 0.2)
                          : Colors.red.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.circle,
                          size: 10,
                          color: (_isConnected ?? false)
                              ? Colors.green
                              : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          (_isConnected ?? false)
                              ? 'Connected'
                              : 'Disconnected',
                          style: TextStyle(
                            color: (_isConnected ?? false)
                                ? Colors.green
                                : Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Endpoint URL',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _urlController,
                decoration: InputDecoration(
                  hintText: 'http://localhost:11434',
                  filled: true,
                  fillColor: theme.colorScheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                onSubmitted: (_) => _saveUrl(),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isConnecting
                          ? null
                          : () async {
                              await _saveUrl(); // Save and test
                              // Also refresh models after connection test
                              await _refreshModels();
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isConnecting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Test Connection'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        await _saveUrl();
                        // Also refresh models after saving URL
                        await _refreshModels();
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Connect'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPromptSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Prompts'),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.3,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            title: const Text('Manage System Prompts'),
            subtitle: const Text('Create and edit reusable system prompts'),
            trailing: const Icon(Icons.chevron_right),
            leading: const Icon(Icons.edit_note),
            onTap: () {
              HapticFeedback.lightImpact();
              context.go('/settings/prompts');
            },
          ),
        ),
      ],
    );
  }

  Widget _buildModelsSection(ThemeData theme) {
    final modelsAsync = ref.watch(modelsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Models',
          trailing: IconButton(
            icon: _isRefreshingModels
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh, size: 20),
            onPressed: _isRefreshingModels
                ? null
                : () async {
                    HapticFeedback.lightImpact();
                    await _refreshModels();
                  },
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.primaryContainer,
              padding: const EdgeInsets.all(8),
            ),
          ),
        ),
        modelsAsync.when(
          data: (models) {
            if (models.isEmpty) {
              return const Text('No models found. Pull one via Termux.');
            }
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: models.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final model = models[index];
                final storage = ref.watch(storageServiceProvider);
                final defaultModel =
                    storage.getSetting(AppConstants.defaultModelKey) ?? '';

                return Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.3,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    title: Text(
                      model.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Row(
                      children: [
                        Text(
                          '${(model.size / 1024 / 1024 / 1024).toStringAsFixed(1)} GB',
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(width: 8),
                        if (model.name.toLowerCase().contains('vision') ||
                            model.name.toLowerCase().contains('llava'))
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.visibility,
                                  size: 12,
                                  color: Colors.blue,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  "Vision",
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Radio<String>(
                          value: model.name,
                          groupValue: defaultModel,
                          onChanged: (val) {
                            storage.saveSetting(
                              AppConstants.defaultModelKey,
                              val,
                            );
                            setState(() {});
                          },
                          activeColor: Colors.blue,
                          visualDensity: VisualDensity.compact,
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.edit,
                            size: 20,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            // Open dialog to set per-model system prompt and settings
                            // For now just show "feature coming soon" or simple dialog
                            //    _showModelSettingsDialog(context, model.name);
                            // We will just show a snackbar since I haven't defined _showModelSettingsDialog yet
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Model specific settings coming soon',
                                ),
                              ),
                            );
                          },
                          visualDensity: VisualDensity.compact,
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            color: theme.colorScheme.error,
                          ),
                          onPressed: () async {
                            HapticFeedback.mediumImpact();
                            await ref
                                .read(ollamaServiceProvider)
                                .deleteModel(model.name);
                            // Use our refresh method to show loading indicator
                            await _refreshModels();
                          },
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text(
            'Error loading models: $e',
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ),
      ],
    );
  }

  Widget _buildPromptEnhancerSection(ThemeData theme) {
    final modelsAsync = ref.watch(modelsProvider);
    final enhancerState = ref.watch(promptEnhancerProvider);
    final selectedModel = enhancerState.selectedModelId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Prompt Enhancer'),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.3,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: false,
              title: const Text(
                'Select Enhancer Model',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                selectedModel ?? 'No model selected',
                style: TextStyle(
                  fontSize: 12,
                  color: selectedModel != null ? Colors.green : Colors.grey,
                ),
              ),
              leading: Icon(
                Icons.auto_awesome,
                color: theme.colorScheme.primary,
              ),
              children: [
                // Edit System Prompt Button
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: OutlinedButton.icon(
                    onPressed: () => _showEditEnhancerPromptDialog(context),
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('View/Edit Enhancer Prompt'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 40),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'This model will enhance prompts with best practices like specificity and structure.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue[800],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                modelsAsync.when(
                  data: (models) {
                    if (models.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'No models available. Pull one via Termux.',
                        ),
                      );
                    }
                    return AnimatedOpacity(
                      opacity: 1.0,
                      duration: const Duration(milliseconds: 300),
                      child: Column(
                        children: [
                          RadioListTile<String?>(
                            title: const Text('None (Disabled)'),
                            value: null,
                            groupValue: selectedModel,
                            onChanged: (val) {
                              HapticFeedback.selectionClick();
                              ref
                                  .read(promptEnhancerProvider.notifier)
                                  .setSelectedModel(null);
                            },
                          ),
                          ...models.map(
                            (m) => RadioListTile<String>(
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      m.name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${(m.size / 1024 / 1024 / 1024).toStringAsFixed(1)} GB',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  if (m.name.toLowerCase().contains('vision') ||
                                      m.name.toLowerCase().contains('llava'))
                                    Padding(
                                      padding: const EdgeInsets.only(left: 8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.withValues(
                                            alpha: 0.2,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: const Text(
                                          'Vision',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.blue,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              value: m.name,
                              groupValue: selectedModel,
                              onChanged: (val) {
                                HapticFeedback.selectionClick();
                                ref
                                    .read(promptEnhancerProvider.notifier)
                                    .setSelectedModel(val);
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Error: $e',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showEditEnhancerPromptDialog(BuildContext context) {
    final controller = TextEditingController(
      text: AppConstants.promptEnhancerSystemPrompt,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enhancer System Prompt'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This prompt instructs the AI how to enhance your prompts:',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 10,
                readOnly: true, // Read-only for now (fixed prompt)
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                ),
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Colors.orange[700],
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'This prompt is optimized for best results. Editing is disabled to ensure consistent enhancement quality.',
                        style: TextStyle(fontSize: 11, color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildUsageLimitsSection(ThemeData theme) {
    final limits = ref.watch(usageLimitsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Usage Limits',
          trailing: IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: () {
              HapticFeedback.lightImpact();
              ref.read(usageLimitsProvider.notifier).reload();
            },
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.primaryContainer,
              padding: const EdgeInsets.all(8),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.3,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              // Chat Creation Metrics
              ListTile(
                leading: Icon(
                  Icons.chat_bubble_outline,
                  color: limits.canCreateFreeChat ? Colors.blue : Colors.red,
                ),
                title: Text(
                  'Chats Created: ${limits.totalChatsCreated}/${AppConstants.freeChatsAllowed}',
                ),
                subtitle: limits.canCreateFreeChat
                    ? null
                    : const Text(
                        'Limit reached - Watch ad to unlock more chats',
                        style: TextStyle(fontSize: 12, color: Colors.red),
                      ),
                trailing: !limits.canCreateFreeChat
                    ? TextButton.icon(
                        onPressed: () => _watchAdForChats(),
                        icon: const Icon(Icons.play_circle, size: 18),
                        label: const Text('Watch Ad'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.blue,
                        ),
                      )
                    : null,
              ),
              const Divider(height: 1),
              // Prompt Enhancements
              ListTile(
                leading: Icon(
                  Icons.auto_awesome,
                  color: limits.hasEnhancerUses ? Colors.blue : Colors.orange,
                ),
                title: Text(
                  'Prompt Enhancements: ${limits.enhancerRemaining}/${AppConstants.freeEnhancementsPerDay}',
                ),
                subtitle: limits.enhancerRemaining > 0
                    ? null
                    : Text(
                        'Resets in ~${limits.hoursUntilEnhancerReset} hours',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                trailing: limits.hasEnhancerUses
                    ? null
                    : TextButton.icon(
                        onPressed: () => _watchAdForEnhancements(),
                        icon: const Icon(Icons.play_circle, size: 18),
                        label: const Text('Watch Ad'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.blue,
                        ),
                      ),
              ),
              const Divider(height: 1),
              // Token Balance
              ListTile(
                leading: Icon(
                  Icons.token,
                  color: limits.remainingTokens > 1000
                      ? Colors.green
                      : Colors.orange,
                ),
                title: Text(
                  'Token Balance: ${limits.remainingTokens}/${limits.tokenBalance}',
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: limits.tokenBalance > 0
                          ? limits.remainingTokens / limits.tokenBalance
                          : 0,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation(
                        limits.remainingTokens > 1000
                            ? Colors.green
                            : Colors.orange,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Total used: ${limits.totalTokensUsed}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ),
                trailing: limits.remainingTokens < 1000
                    ? TextButton.icon(
                        onPressed: () => _watchAdForTokens(),
                        icon: const Icon(Icons.play_circle, size: 18),
                        label: const Text('+10K'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.green,
                        ),
                      )
                    : null,
              ),
              const Divider(height: 1),
              // Info text
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Ads help support development—thanks!',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.info, size: 16),
                      onPressed: _showAdsInfoDialog,
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _watchAdForChats() async {
    HapticFeedback.lightImpact();

    if (!await _adService.hasInternetConnection()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connect to WiFi/Data to watch ad and unlock.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    await _adService.showRewardedAd(
      onUserEarnedReward: (reward) async {
        await ref
            .read(usageLimitsProvider.notifier)
            .addChatCredits(AppConstants.chatsPerAdWatch);
        if (mounted) {
          HapticFeedback.heavyImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unlocked 5 more chats!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      },
      onFailed: (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ad failed: $error'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
    );
  }

  Future<void> _watchAdForEnhancements() async {
    HapticFeedback.lightImpact();

    if (!await _adService.hasInternetConnection()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connect to WiFi/Data to watch ad and unlock.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    await _adService.showRewardedAd(
      onUserEarnedReward: (reward) async {
        await ref
            .read(usageLimitsProvider.notifier)
            .addEnhancerUses(AppConstants.enhancementsPerAdWatch);
        if (mounted) {
          HapticFeedback.heavyImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unlocked 5 more enhancements!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      },
      onFailed: (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ad failed: $error'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
    );
  }

  Future<void> _watchAdForTokens() async {
    HapticFeedback.lightImpact();

    if (!await _adService.hasInternetConnection()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connect to WiFi/Data to watch ad and unlock.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    await _adService.showRewardedAd(
      onUserEarnedReward: (reward) async {
        await ref
            .read(usageLimitsProvider.notifier)
            .addTokens(AppConstants.tokensPerAdWatch);
        if (mounted) {
          HapticFeedback.heavyImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Added 10,000 tokens!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      },
      onFailed: (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ad failed: $error'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
    );
  }

  Widget _buildStorageSection(ThemeData theme, dynamic storage) {
    bool autoSave = storage.getSetting(
      AppConstants.autoSaveChatsKey,
      defaultValue: true,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Chats & Storage'),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.3,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Auto-save chats'),
                value: autoSave,
                onChanged: (val) async {
                  HapticFeedback.lightImpact();
                  await storage.saveSetting(AppConstants.autoSaveChatsKey, val);
                  setState(() {}); // Rebuild
                },
              ),
              ListTile(
                title: Text(
                  'Clear All History',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                onTap: () async {
                  HapticFeedback.lightImpact();
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('Clear All History?'),
                      content: const Text(
                        'This will delete all chats permanently.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(c, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(c, true),
                          child: const Text(
                            'Clear',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    await storage.clearAllChats();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('History cleared')),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAppearanceSection(ThemeData theme, dynamic storage) {
    final themeMode = ref.watch(themeProvider);
    bool haptic = storage.getSetting(
      AppConstants.hapticFeedbackKey,
      defaultValue: false,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Appearance'),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.3,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Theme', style: TextStyle(fontSize: 16)),
                    const SizedBox(height: 12),
                    SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.light,
                          label: Text('Light'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          label: Text('Dark'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.system,
                          label: Text('System'),
                        ),
                      ],
                      selected: {themeMode},
                      onSelectionChanged: (Set<ThemeMode> newSelection) {
                        HapticFeedback.selectionClick();
                        ref
                            .read(themeProvider.notifier)
                            .setThemeMode(newSelection.first);
                      },
                      style: ButtonStyle(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
              ),
              SwitchListTile(
                title: const Text('Haptic Feedback'),
                value: haptic,
                onChanged: (val) async {
                  if (val) HapticFeedback.lightImpact();
                  await storage.saveSetting(
                    AppConstants.hapticFeedbackKey,
                    val,
                  );
                  setState(() {});
                },
              ),
              ListTile(
                title: const Text('Chat Customization'),
                subtitle: const Text('Colors, Fonts, Radius'),
                trailing: const Icon(Icons.chevron_right),
                leading: const Icon(Icons.palette_outlined),
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.go('/settings/customization');
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAboutSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('About'),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.3,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              // ListTile(
              //   title: const Text('App Version'),
              //   trailing: Text(
              //     _version,
              //     style: const TextStyle(color: Colors.grey),
              //   ),
              // ),
              ListTile(
                title: const Text('Privacy Policy'),
                leading: const Icon(Icons.privacy_tip_outlined, size: 20),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => _showMarkdownDialog(
                  context,
                  'Privacy Policy',
                  LegalConstants.privacyPolicy,
                ),
              ),
              ListTile(
                title: const Text('About the App'),
                leading: const Icon(Icons.info_outline, size: 20),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => _showMarkdownDialog(
                  context,
                  'About Pocket LLM Lite',
                  LegalConstants.aboutApp,
                ),
              ),
              ListTile(
                title: const Text('License'),
                leading: const Icon(Icons.description_outlined, size: 20),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => _showMarkdownDialog(
                  context,
                  'License',
                  LegalConstants.license,
                ),
              ),
              ListTile(
                title: const Text('Documentation & Setup'),
                leading: const Icon(Icons.book_outlined, size: 20),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.go('/settings/docs');
                },
              ),
              ListTile(
                title: const Text('Version'),
                subtitle: Text(_version),
                leading: const Icon(Icons.verified_outlined, size: 20),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showAdsInfoDialog() {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Why Ads?',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Supporting Development',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Even though Pocket LLM Lite works completely offline, '
                    'there are still costs associated with developing and maintaining the app:',
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '• Development time and effort',
                    style: TextStyle(fontSize: 14),
                  ),
                  const Text(
                    '• Testing across devices and platforms',
                    style: TextStyle(fontSize: 14),
                  ),
                  const Text(
                    '• App store fees and platform costs',
                    style: TextStyle(fontSize: 14),
                  ),
                  const Text(
                    '• Ongoing maintenance and updates',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Ads help us continue improving the app and adding new features '
                    'while keeping it free to use. Thank you for your support!',
                    style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                  child: const Text('Got it'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMarkdownDialog(BuildContext context, String title, String content) {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Markdown(
                data: content,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                onTapLink: (text, href, title) async {
                  if (href != null) {
                    final uri = Uri.parse(href);
                    if (await canLaunchUrl(uri)) await launchUrl(uri);
                  }
                },
                styleSheet: MarkdownStyleSheet.fromTheme(
                  Theme.of(context),
                ).copyWith(p: Theme.of(context).textTheme.bodyMedium),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
