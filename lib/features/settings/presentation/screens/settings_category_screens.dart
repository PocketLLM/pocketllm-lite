import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/widgets/m3_app_bar.dart';
import '../../../../core/widgets/update_dialog.dart';
import '../../../../services/update_service.dart';
import '../../../chat/presentation/providers/models_provider.dart';
import '../../../chat/presentation/providers/prompt_enhancer_provider.dart';
import '../widgets/export_dialog.dart';
import '../widgets/import_dialog.dart';
import '../widgets/model_settings_dialog.dart';

// ==========================================
// 1. PROMPTS & TEMPLATES SETTINGS SCREEN
// ==========================================
class PromptsTemplatesSettingsScreen extends ConsumerWidget {
  const PromptsTemplatesSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final modelsAsync = ref.watch(modelsProvider);
    final enhancerState = ref.watch(promptEnhancerProvider);
    final selectedModel = enhancerState.selectedModelId;

    return Scaffold(
      appBar: M3AppBar(
        title: 'Prompts & Templates',
        subtitle: 'Configure AI personas, templates, and enhancers',
        onBack: () => Navigator.pop(context),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            title: const Text('Manage AI Personas'),
            subtitle: const Text('Custom instructions, icons, and temperature overrides'),
            leading: Icon(Icons.face_retouching_natural, color: theme.colorScheme.primary),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              HapticFeedback.lightImpact();
              context.push('/settings/personas');
            },
          ),
          const Divider(height: 1, indent: 56),
          ListTile(
            title: const Text('Manage Agent Skills'),
            subtitle: const Text('Install, import, and CRUD custom agent skills'),
            leading: Icon(Icons.extension_rounded, color: theme.colorScheme.primary),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              HapticFeedback.lightImpact();
              context.push('/settings/skills');
            },
          ),
          const Divider(height: 1, indent: 56),
          ListTile(
            title: const Text('Manage System Prompts'),
            subtitle: const Text('Create and edit reusable AI personas'),
            leading: Icon(Icons.edit_note, color: theme.colorScheme.primary),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              HapticFeedback.lightImpact();
              context.push('/settings/prompts');
            },
          ),
          const Divider(height: 1, indent: 56),
          ListTile(
            title: const Text('Message Templates'),
            subtitle: const Text('Manage quick reply snippets'),
            leading: Icon(Icons.bolt, color: theme.colorScheme.primary),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              HapticFeedback.lightImpact();
              context.push('/settings/templates');
            },
          ),
          const Divider(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              'Prompt Enhancer',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          Theme(
            data: theme.copyWith(dividerColor: Colors.transparent),
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
                  color: selectedModel != null
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              leading: Icon(
                Icons.auto_awesome,
                color: theme.colorScheme.primary,
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'This model will enhance prompts with best practices like specificity and structure.',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onPrimaryContainer,
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
                        child: Text('No models available. Pull one via Termux.'),
                      );
                    }
                    return Column(
                      children: [
                        RadioListTile<String?>(
                          title: const Text('None (Disabled)'),
                          value: null,
                          groupValue: selectedModel,
                          onChanged: (val) {
                            HapticFeedback.selectionClick();
                            ref.read(promptEnhancerProvider.notifier).setSelectedModel(null);
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
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.tertiary.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text('Vision', style: TextStyle(fontSize: 10)),
                                    ),
                                  ),
                              ],
                            ),
                            value: m.name,
                            groupValue: selectedModel,
                            onChanged: (val) {
                              HapticFeedback.selectionClick();
                              ref.read(promptEnhancerProvider.notifier).setSelectedModel(val);
                            },
                          ),
                        ),
                      ],
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Error: $e', style: TextStyle(color: theme.colorScheme.error)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEditEnhancerPromptDialog(BuildContext context) {
    final controller = TextEditingController(text: AppConstants.promptEnhancerSystemPrompt);

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
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 10,
                readOnly: true,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                ),
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.tertiaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Theme.of(context).colorScheme.tertiary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This prompt is optimized for best results. Editing is disabled to ensure consistent enhancement quality.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onTertiaryContainer,
                        ),
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
}

// ==========================================
// 2. MODELS & INFERENCE SETTINGS SCREEN
// ==========================================
class ModelsInferenceSettingsScreen extends ConsumerStatefulWidget {
  const ModelsInferenceSettingsScreen({super.key});

  @override
  ConsumerState<ModelsInferenceSettingsScreen> createState() => _ModelsInferenceSettingsScreenState();
}

class _ModelsInferenceSettingsScreenState extends ConsumerState<ModelsInferenceSettingsScreen> {
  bool _isRefreshing = false;

  Future<void> _refreshModels() async {
    setState(() => _isRefreshing = true);
    ref.invalidate(modelsProvider);
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) setState(() => _isRefreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final modelsAsync = ref.watch(modelsProvider);
    final storage = ref.watch(storageServiceProvider);
    final defaultModel = storage.getSetting(AppConstants.defaultModelKey) ?? '';

    return Scaffold(
      appBar: M3AppBar(
        title: 'Models & Inference',
        subtitle: 'Configure local llama.cpp and Ollama models',
        onBack: () => Navigator.pop(context),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            title: const Text('Local GGUF Models & Catalog'),
            subtitle: const Text('Browse GGUF catalog profiles, import files, and load to RAM'),
            leading: Icon(Icons.memory_rounded, color: theme.colorScheme.primary),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              HapticFeedback.lightImpact();
              context.push('/settings/model-catalog');
            },
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ollama Host Models',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.add, size: 20),
                    tooltip: 'Download Model',
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      context.push('/model-browser');
                    },
                    style: IconButton.styleFrom(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: _isRefreshing
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.refresh, size: 20),
                    onPressed: _isRefreshing ? null : _refreshModels,
                    style: IconButton.styleFrom(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          modelsAsync.when(
            data: (models) {
              if (models.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('No models found. Pull one using the + button.')),
                );
              }
              return Column(
                children: [
                  for (final model in models) ...[
                    ListTile(
                      title: Text(model.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Row(
                        children: [
                          Text('${(model.size / 1024 / 1024 / 1024).toStringAsFixed(1)} GB', style: const TextStyle(fontSize: 12)),
                          const SizedBox(width: 8),
                          if (model.name.toLowerCase().contains('vision') || model.name.toLowerCase().contains('llava'))
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.tertiary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.visibility, size: 12, color: theme.colorScheme.tertiary),
                                  const SizedBox(width: 4),
                                  Text("Vision", style: TextStyle(fontSize: 10, color: theme.colorScheme.tertiary)),
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
                              HapticFeedback.selectionClick();
                              storage.saveSetting(AppConstants.defaultModelKey, val);
                              setState(() {});
                            },
                            activeColor: theme.colorScheme.primary,
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              showDialog(
                                context: context,
                                builder: (context) => ModelSettingsDialog(modelName: model.name),
                              );
                            },
                          ),
                          IconButton(
                            icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                            onPressed: () async {
                              HapticFeedback.mediumImpact();
                              await ref.read(ollamaServiceProvider).deleteModel(model.name);
                              _refreshModels();
                            },
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                  ],
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('Error: $e', style: TextStyle(color: theme.colorScheme.error))),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 3. KNOWLEDGE & SEARCH SETTINGS SCREEN
// ==========================================
class KnowledgeSearchSettingsScreen extends ConsumerStatefulWidget {
  const KnowledgeSearchSettingsScreen({super.key});

  @override
  ConsumerState<KnowledgeSearchSettingsScreen> createState() => _KnowledgeSearchSettingsScreenState();
}

class _KnowledgeSearchSettingsScreenState extends ConsumerState<KnowledgeSearchSettingsScreen> {
  late TextEditingController _tavilyKeyController;

  @override
  void initState() {
    super.initState();
    final storage = ref.read(storageServiceProvider);
    final key = storage.getSetting('tavily_api_key', defaultValue: '') as String? ?? '';
    _tavilyKeyController = TextEditingController(text: key);
  }

  @override
  void dispose() {
    _tavilyKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: M3AppBar(
        title: 'Knowledge & Search',
        subtitle: 'Configure offline RAG documents and search APIs',
        onBack: () => Navigator.pop(context),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            title: const Text('Knowledge Base (Documents)'),
            subtitle: const Text('Manage Retrieval-Augmented Generation (RAG) files'),
            leading: Icon(Icons.library_books, color: theme.colorScheme.primary),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              HapticFeedback.lightImpact();
              context.push('/document-manager');
            },
          ),
          const Divider(height: 32),
          Text(
            'Web Search API Integration',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'A Tavily API key enables real-time search capabilities for local AI models. Get a free key at tavily.com.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _tavilyKeyController,
            obscureText: true,
            decoration: InputDecoration(
              hintText: 'Enter your Tavily API Key (tvly-...)',
              labelText: 'Tavily API Key',
              prefixIcon: const Icon(Icons.vpn_key_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.15),
            ),
            onChanged: (val) async {
              final storage = ref.read(storageServiceProvider);
              await storage.saveSetting('tavily_api_key', val.trim());
            },
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 4. CHATS & DATA MANAGEMENT SCREEN
// ==========================================
class ChatsDataSettingsScreen extends ConsumerStatefulWidget {
  const ChatsDataSettingsScreen({super.key});

  @override
  ConsumerState<ChatsDataSettingsScreen> createState() => _ChatsDataSettingsScreenState();
}

class _ChatsDataSettingsScreenState extends ConsumerState<ChatsDataSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final storage = ref.watch(storageServiceProvider);
    final autoSave = storage.getSetting(AppConstants.autoSaveChatsKey, defaultValue: true);

    return Scaffold(
      appBar: M3AppBar(
        title: 'Chats & Data',
        subtitle: 'Manage local database backup and data cleanup',
        onBack: () => Navigator.pop(context),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('Auto-save chats'),
            subtitle: const Text('Persist chat history session databases'),
            value: autoSave,
            onChanged: (val) async {
              HapticFeedback.lightImpact();
              await storage.saveSetting(AppConstants.autoSaveChatsKey, val);
              setState(() {});
            },
          ),
          const Divider(height: 1),
          ListTile(
            title: const Text('Export Data'),
            subtitle: const Text('Export chats and custom prompts to JSON'),
            leading: Icon(Icons.download, color: theme.colorScheme.primary),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              HapticFeedback.lightImpact();
              showDialog(
                context: context,
                builder: (context) => const ExportDialog(),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            title: const Text('Import Data'),
            subtitle: const Text('Restore chats and prompts from JSON backups'),
            leading: Icon(Icons.upload, color: theme.colorScheme.primary),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              HapticFeedback.lightImpact();
              showDialog(
                context: context,
                builder: (context) => const ImportDialog(),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            title: const Text('Starred Messages'),
            subtitle: const Text('View bookmarked messages'),
            leading: Icon(Icons.star_outline, color: theme.colorScheme.primary),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              HapticFeedback.lightImpact();
              context.push('/settings/starred-messages');
            },
          ),
          const Divider(height: 1),
          ListTile(
            title: const Text('Media Gallery'),
            subtitle: const Text('Browse all shared images and attachments'),
            leading: Icon(Icons.photo_library_outlined, color: theme.colorScheme.primary),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              HapticFeedback.lightImpact();
              context.push('/settings/media-gallery');
            },
          ),
          const Divider(height: 1),
          ListTile(
            title: const Text('Tag Management'),
            subtitle: const Text('Organize and rename chat session tags'),
            leading: Icon(Icons.label_outline, color: theme.colorScheme.primary),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              HapticFeedback.lightImpact();
              context.push('/settings/tags');
            },
          ),
          const Divider(height: 24),
          ListTile(
            title: Text('Clear All History', style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.bold)),
            subtitle: const Text('Permanently wipe out local chat databases'),
            leading: Icon(Icons.delete_sweep_rounded, color: theme.colorScheme.error),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              HapticFeedback.mediumImpact();
              final confirm = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('Clear All History?'),
                  content: const Text('This will delete all chats permanently. This operation is irreversible.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(c, true),
                      style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
                      child: const Text('Clear permanently'),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await storage.clearAllChats();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('History cleared successfully'), behavior: SnackBarBehavior.floating),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 5. APPEARANCE & THEMES SETTINGS SCREEN
// ==========================================
class AppearanceThemesSettingsScreen extends ConsumerStatefulWidget {
  const AppearanceThemesSettingsScreen({super.key});

  @override
  ConsumerState<AppearanceThemesSettingsScreen> createState() => _AppearanceThemesSettingsScreenState();
}

class _AppearanceThemesSettingsScreenState extends ConsumerState<AppearanceThemesSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeProvider);
    final storage = ref.watch(storageServiceProvider);
    final haptic = storage.getSetting(AppConstants.hapticFeedbackKey, defaultValue: false);

    return Scaffold(
      appBar: M3AppBar(
        title: 'Appearance & Themes',
        subtitle: 'Configure app theme mode, accent seed, and haptics',
        onBack: () => Navigator.pop(context),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Theme Mode',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                    ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                    ButtonSegment(value: ThemeMode.system, label: Text('System')),
                  ],
                  selected: {themeMode},
                  onSelectionChanged: (Set<ThemeMode> newSelection) {
                    HapticFeedback.selectionClick();
                    ref.read(themeProvider.notifier).setThemeMode(newSelection.first);
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          SwitchListTile(
            title: const Text('Haptic Feedback'),
            subtitle: const Text('Subtle haptic sensations on touch interaction'),
            value: haptic,
            onChanged: (val) async {
              if (val) HapticFeedback.lightImpact();
              await storage.saveSetting(AppConstants.hapticFeedbackKey, val);
              setState(() {});
            },
          ),
          const Divider(height: 1),
          ListTile(
            title: const Text('Chat UI Customization'),
            subtitle: const Text('Colors, Fonts, Message Corner Radius'),
            leading: Icon(Icons.palette_outlined, color: theme.colorScheme.primary),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              HapticFeedback.lightImpact();
              context.push('/settings/customization');
            },
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 6. SYSTEM TOOLS & DIAGNOSTICS SCREEN
// ==========================================
class SystemToolsSettingsScreen extends ConsumerStatefulWidget {
  const SystemToolsSettingsScreen({super.key});

  @override
  ConsumerState<SystemToolsSettingsScreen> createState() => _SystemToolsSettingsScreenState();
}

class _SystemToolsSettingsScreenState extends ConsumerState<SystemToolsSettingsScreen> {
  final UpdateService _updateService = UpdateService();
  bool _autoUpdateEnabled = true;
  bool _isCheckingForUpdates = false;
  String _version = 'Loading...';

  @override
  void initState() {
    super.initState();
    _loadUpdateSettings();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() => _version = '${info.version} (${info.buildNumber})');
    }
  }

  Future<void> _loadUpdateSettings() async {
    final enabled = await _updateService.isAutoUpdateEnabled();
    if (mounted) setState(() => _autoUpdateEnabled = enabled);
  }

  Future<void> _toggleAutoUpdate(bool value) async {
    HapticFeedback.selectionClick();
    await _updateService.setAutoUpdateEnabled(value);
    if (mounted) setState(() => _autoUpdateEnabled = value);
  }

  Future<void> _checkForUpdatesManually() async {
    HapticFeedback.mediumImpact();
    setState(() => _isCheckingForUpdates = true);

    try {
      await _updateService.clearDismissedVersion();
      final result = await _updateService.checkForUpdates(force: true);

      if (!mounted) return;

      if (result.updateAvailable && result.release != null) {
        await UpdateDialog.show(context, result.release!);
      } else if (result.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error checking for updates: ${result.error}'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('You are using the latest version! 🎉'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCheckingForUpdates = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: M3AppBar(
        title: 'System & Diagnostics',
        subtitle: 'Configure device updates, benchmark, and performance',
        onBack: () => Navigator.pop(context),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            title: const Text('Inference Benchmark'),
            subtitle: const Text('Measure local model tokens per second and latency'),
            leading: Icon(Icons.rocket_launch_outlined, color: theme.colorScheme.primary),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              HapticFeedback.lightImpact();
              context.push('/settings/benchmark');
            },
          ),
          const Divider(height: 1),
          ListTile(
            title: const Text('User Display Profile'),
            subtitle: const Text('Customize your displays, name, and details'),
            leading: Icon(Icons.person_outline, color: theme.colorScheme.primary),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              HapticFeedback.lightImpact();
              context.push('/settings/profile');
            },
          ),
          const Divider(height: 1),
          ListTile(
            title: const Text('Activity History Log'),
            subtitle: const Text('View and query past operations and usage statistics'),
            leading: Icon(Icons.history, color: theme.colorScheme.primary),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              HapticFeedback.lightImpact();
              context.push('/settings/activity-log');
            },
          ),
          const Divider(height: 1),
          ListTile(
            title: const Text('Usage Statistics Tracker'),
            subtitle: const Text('View active prompt enhancement and token analytics'),
            leading: Icon(Icons.bar_chart_outlined, color: theme.colorScheme.primary),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              HapticFeedback.lightImpact();
              context.push('/settings/statistics');
            },
          ),
          const Divider(height: 1),
          ListTile(
            title: const Text('Debug Error Log'),
            subtitle: const Text('View system diagnostics error records'),
            leading: Icon(Icons.bug_report_outlined, color: theme.colorScheme.primary),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              HapticFeedback.lightImpact();
              context.push('/settings/error-log');
            },
          ),
          const Divider(height: 24),
          Text(
            'Application OTA Updates',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('Auto-check for Updates'),
            subtitle: const Text('Check for updates when the application opens'),
            value: _autoUpdateEnabled,
            onChanged: _toggleAutoUpdate,
            secondary: Icon(
              Icons.update,
              color: _autoUpdateEnabled ? theme.colorScheme.primary : Colors.grey,
            ),
          ),
          const Divider(height: 1),
          ListTile(
            title: const Text('Check for Updates Now'),
            subtitle: const Text('Manually query latest GitHub releases'),
            leading: _isCheckingForUpdates
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
            trailing: _isCheckingForUpdates ? null : const Icon(Icons.chevron_right),
            onTap: _isCheckingForUpdates ? null : _checkForUpdatesManually,
          ),
          const Divider(height: 1),
          ListTile(
            title: const Text('View Releases on GitHub'),
            subtitle: const Text('Open repository releases catalog page'),
            leading: const Icon(Icons.open_in_new),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              HapticFeedback.lightImpact();
              final url = Uri.parse(_updateService.getReleasesPageUrl());
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 18, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Releases are loaded directly from GitHub. PocketLLM is currently running version $_version.',
                    style: TextStyle(fontSize: 12, color: Colors.blue[800]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
