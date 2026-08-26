import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets/m3_app_bar.dart';
import '../../../../core/constants/legal_constants.dart';
import '../../core/utils/url_validator.dart';

import '../../core/providers.dart';
import 'presentation/screens/settings_category_screens.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _version = 'Loading...';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() => _version = '${info.version} (${info.buildNumber})');
    }
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
          title: const Text('Model Store'),
          subtitle: const Text(
            'Discover, download, import, and inspect on-device models',
          ),
          leading: Icon(Icons.storefront, color: theme.colorScheme.primary),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/settings/model-catalog'),
        ),
        const Divider(height: 1, indent: 56),
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
          title: const Text('Providers & Ollama'),
          subtitle: const Text(
              'Connection state, configured host models, and inference settings'),
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
          title: const Text('Knowledge Base'),
          subtitle: const Text(
              'Retrieval setup, documents, indexing tasks, and citations'),
          leading: Icon(Icons.library_books, color: theme.colorScheme.primary),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            HapticFeedback.lightImpact();
            context.push('/document-manager');
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
          title: const Text('Privacy & Network Centre',
              style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: const Text(
              'Strict Offline Mode, endpoint transparency, connection audit log, and privacy controls'),
          leading: Icon(Icons.shield_rounded, color: theme.colorScheme.primary),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            HapticFeedback.lightImpact();
            context.push('/settings/privacy-network');
          },
        ),
        const Divider(height: 1, indent: 56),
        ListTile(
          title: const Text('Prompt Lab & Engineering'),
          subtitle: const Text(
              'Variable replacement, sampling overrides, and parameter benchmarks'),
          leading:
              Icon(Icons.science_outlined, color: theme.colorScheme.primary),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            HapticFeedback.lightImpact();
            context.push('/settings/prompt-lab');
          },
        ),
        const Divider(height: 1, indent: 56),
        ListTile(
          title: const Text('Audio Workspace & Speech'),
          subtitle: const Text(
              'Offline speech transcription using an installed Whisper model'),
          leading:
              Icon(Icons.graphic_eq_rounded, color: theme.colorScheme.primary),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            HapticFeedback.lightImpact();
            context.push('/settings/audio-transcription');
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
                    final uri = Uri.tryParse(href);
                    if (uri == null || !UrlValidator.isSecureUrl(uri)) return;
                    try {
                      await ref
                          .read(externalNavigationServiceProvider)
                          .openHttpUrl(
                            uri,
                            trigger: 'legal_document_link',
                          );
                    } catch (error) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(error.toString())),
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
