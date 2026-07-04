import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets/m3_app_bar.dart';
import '../../../../core/constants/legal_constants.dart';
import '../../core/utils/url_validator.dart';

import '../../core/constants/app_constants.dart';
import '../../core/providers.dart';
import '../chat/presentation/providers/models_provider.dart';
import 'presentation/screens/settings_category_screens.dart';

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

    Future.delayed(Duration.zero, () {
      _refreshModels();
    });
  }

  Future<void> _refreshModels() async {
    ref.invalidate(modelsProvider);
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

    if (!UrlValidator.isHttpUrlString(url)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Invalid URL: Must start with http:// or https://',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final storage = ref.read(storageServiceProvider);
    await storage.saveSetting(AppConstants.ollamaBaseUrlKey, url);
    ref.read(ollamaServiceProvider).updateBaseUrl(url);

    await _checkConnection();
    ref.invalidate(modelsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      onPopInvokedWithResult: (didPop, result) async {
        if (GoRouter.of(context).canPop()) {
          context.pop();
        } else {
          context.go('/chat');
        }
      },
      child: Scaffold(
        appBar: M3AppBar(
          title: 'Settings',
          onBack: () {
            if (GoRouter.of(context).canPop()) {
              context.pop();
            } else {
              context.go('/chat');
            }
          },
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildConnectionSection(theme),
            const SizedBox(height: 24),
            _buildCategoryNavList(theme),
            const SizedBox(height: 24),
            _buildAboutSection(theme),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryNavList(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Configuration Categories'),
        ListTile(
          title: const Text('Prompts & Templates'),
          subtitle: const Text(
              'AI personas, custom skills, system prompts, quick templates, and enhancer'),
          leading: Icon(Icons.face_retouching_natural,
              color: theme.colorScheme.primary),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const PromptsTemplatesSettingsScreen()),
            );
          },
        ),
        const Divider(height: 1, indent: 56),
        ListTile(
          title: const Text('Models & Inference'),
          subtitle: const Text(
              'Manage local GGUF catalog models and configure active Ollama models'),
          leading: Icon(Icons.memory_rounded, color: theme.colorScheme.primary),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const ModelsInferenceSettingsScreen()),
            );
          },
        ),
        const Divider(height: 1, indent: 56),
        ListTile(
          title: const Text('Knowledge Base & Web Search'),
          subtitle: const Text(
              'Configure RAG documents and real-time search engine settings'),
          leading: Icon(Icons.library_books, color: theme.colorScheme.primary),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const KnowledgeSearchSettingsScreen()),
            );
          },
        ),
        const Divider(height: 1, indent: 56),
        ListTile(
          title: const Text('Chats & Local Data'),
          subtitle: const Text(
              'Configure auto-save, JSON backup exports, starred messages, and tags'),
          leading: Icon(Icons.forum_outlined, color: theme.colorScheme.primary),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const ChatsDataSettingsScreen()),
            );
          },
        ),
        const Divider(height: 1, indent: 56),
        ListTile(
          title: const Text('Appearance & Themes'),
          subtitle: const Text(
              'Light/dark modes, custom color palettes, and haptic feedback toggles'),
          leading:
              Icon(Icons.palette_outlined, color: theme.colorScheme.primary),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const AppearanceThemesSettingsScreen()),
            );
          },
        ),
        const Divider(height: 1, indent: 56),
        ListTile(
          title: const Text('System, Benchmark & Updates'),
          subtitle: const Text(
              'Run speed benchmarks, activity/error logs, and check OTA updates'),
          leading: Icon(Icons.tune_rounded, color: theme.colorScheme.primary),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const SystemToolsSettingsScreen()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, {Widget? trailing}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: colorScheme.primary,
            ),
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
                          ? theme.colorScheme.primary.withValues(alpha: 0.15)
                          : theme.colorScheme.error.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.circle,
                          size: 8,
                          color: (_isConnected ?? false)
                              ? theme.colorScheme.primary
                              : theme.colorScheme.error,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          (_isConnected ?? false)
                              ? 'Connected'
                              : 'Disconnected',
                          style: TextStyle(
                            color: (_isConnected ?? false)
                                ? theme.colorScheme.primary
                                : theme.colorScheme.error,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Endpoint URL',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
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
                              await _saveUrl();
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
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: theme.colorScheme.onPrimary,
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
                    if (UrlValidator.isSecureUrl(uri) &&
                        await canLaunchUrl(uri)) {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    }
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
