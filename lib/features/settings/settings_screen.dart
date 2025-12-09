import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/legal_constants.dart';

import '../../core/constants/app_constants.dart';
import '../../core/providers.dart';
import '../../core/theme/theme_provider.dart';
import '../chat/presentation/providers/models_provider.dart';

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
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
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
    ref.refresh(modelsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final storage = ref.watch(storageServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildConnectionSection(theme),
          const SizedBox(height: 24),
          _buildPromptSection(theme),
          const SizedBox(height: 24),
          _buildModelsSection(theme),
          const SizedBox(height: 24),
          _buildStorageSection(theme, storage),
          const SizedBox(height: 24),
          _buildAppearanceSection(theme, storage),
          const SizedBox(height: 24),
          _buildAboutSection(theme),
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
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
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
                          ? Colors.green.withOpacity(0.2)
                          : Colors.red.withOpacity(0.2),
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
                      onPressed: () => _saveUrl(),
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
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            title: const Text('Manage System Prompts'),
            subtitle: const Text('Create and edit reusable system prompts'),
            trailing: const Icon(Icons.chevron_right),
            leading: const Icon(Icons.edit_note),
            onTap: () {
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
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: () => ref.refresh(modelsProvider),
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
                final isDefault = defaultModel == model.name;

                return Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withOpacity(0.3),
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
                              color: Colors.blue.withOpacity(0.2),
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
                            await ref
                                .read(ollamaServiceProvider)
                                .deleteModel(model.name);
                            ref.refresh(modelsProvider);
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
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Auto-save chats'),
                value: autoSave,
                onChanged: (val) async {
                  await storage.saveSetting(AppConstants.autoSaveChatsKey, val);
                  setState(() {}); // Rebuild
                },
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
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
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
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
              const Divider(height: 1, indent: 16, endIndent: 16),
              SwitchListTile(
                title: const Text('Haptic Feedback'),
                value: haptic,
                onChanged: (val) async {
                  await storage.saveSetting(
                    AppConstants.hapticFeedbackKey,
                    val,
                  );
                  setState(() {});
                },
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                title: const Text('Chat Customization'),
                subtitle: const Text('Colors, Fonts, Radius'),
                trailing: const Icon(Icons.chevron_right),
                leading: const Icon(Icons.palette_outlined),
                onTap: () {
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
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              ListTile(
                title: const Text('App Version'),
                trailing: Text(
                  _version,
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
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
              const Divider(height: 1, indent: 16, endIndent: 16),
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
              const Divider(height: 1, indent: 16, endIndent: 16),
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
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                title: const Text('Documentation & Setup'),
                leading: const Icon(Icons.book_outlined, size: 20),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () {
                  context.go('/settings/docs');
                },
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                title: const Text('Source Code'),
                leading: const Icon(Icons.code, size: 20),
                subtitle: const Text('github.com/PocketLLM/pocketllm-lite'),
                trailing: const Icon(Icons.open_in_new, size: 20),
                onTap: () async {
                  final uri = Uri.parse(
                    'https://github.com/PocketLLM/pocketllm-lite',
                  );
                  if (await canLaunchUrl(uri)) await launchUrl(uri);
                },
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                title: const Text('Developer'),
                leading: const Icon(Icons.person_outline, size: 20),
                subtitle: const Text('github.com/Mr-Dark-debug'),
                trailing: const Icon(Icons.open_in_new, size: 20),
                onTap: () async {
                  final uri = Uri.parse('https://github.com/Mr-Dark-debug');
                  if (await canLaunchUrl(uri)) await launchUrl(uri);
                },
              ),
            ],
          ),
        ),
      ],
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
