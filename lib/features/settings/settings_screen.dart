import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/settings_provider.dart';
import '../../providers/ollama_provider.dart';
import '../../providers/chat_provider.dart';
import '../../models/ollama_model.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final TextEditingController _endpointController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    // Initialize controller with current value
    final settings = ref.read(settingsProvider).value;
    if (settings != null) {
      _endpointController.text = settings.ollamaEndpoint;
    }
  }

  @override
  void dispose() {
    _endpointController.dispose();
    super.dispose();
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Ollama Connection Help'),
            content: const SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Termux (Android):',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('1. Install Termux & Ollama'),
                  Text('2. Run `ollama serve`'),
                  Text('3. Use default: http://localhost:11434'),
                  SizedBox(height: 12),
                  Text(
                    'Android Emulator:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('1. Run Ollama on your PC'),
                  Text('2. Run `adb reverse tcp:11434 tcp:11434`'),
                  Text('3. Use: http://10.0.2.2:11434'),
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

  Future<void> _testConnection() async {
    final status = ref.read(connectionStatusProvider.notifier);
    final connected =
        await status
            .build(); // Force re-check? calling build returns future but doesn't update state.
    // Better to invalidate.
    ref.invalidate(connectionStatusProvider);
    // Wait for the new value
    // We can show a snackbar based on the result.
    // A bit hacky to wait for riverpod update in a sync function without listening.
    // Let's just manually call check with current text.
    final service = ref.read(ollamaServiceProvider);
    final result = await service.checkConnection(_endpointController.text);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result ? 'Connected Successfully!' : 'Connection Failed',
          ),
          backgroundColor: result ? Colors.green : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);
    final connectionStatusAsync = ref.watch(connectionStatusProvider);
    final availableModelsAsync = ref.watch(availableModelsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
        data: (settings) {
          return ListView(
            children: [
              _buildOllamaSection(context, settings, connectionStatusAsync),
              const Divider(),
              _buildModelsSection(context, settings, availableModelsAsync),
              const Divider(),
              _buildAppearanceSection(context, settings),
              const Divider(),
              _buildStorageSection(context, settings),
              const Divider(),
              _buildAboutSection(context),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOllamaSection(
    BuildContext context,
    dynamic settings,
    AsyncValue<bool> connectionStatus,
  ) {
    final isConnected = connectionStatus.value ?? false;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Ollama Connection',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color:
                      isConnected
                          ? Colors.green.withOpacity(0.2)
                          : Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isConnected ? Colors.green : Colors.red,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.circle,
                      size: 12,
                      color: isConnected ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isConnected ? 'Connected' : 'Disconnected',
                      style: TextStyle(
                        color: isConnected ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Form(
            key: _formKey,
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _endpointController,
                    decoration: const InputDecoration(
                      labelText: 'Endpoint URL',
                      border: OutlineInputBorder(),
                      hintText: 'http://localhost:11434',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Required';
                      if (Uri.tryParse(value) == null) return 'Invalid URL';
                      return null;
                    },
                    onFieldSubmitted: (value) {
                      if (_formKey.currentState!.validate()) {
                        ref
                            .read(settingsProvider.notifier)
                            .updateEndpoint(value);
                        ref.invalidate(connectionStatusProvider);
                      }
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.help_outline),
                  onPressed: () => _showHelpDialog(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _testConnection,
                  child: const Text('Test Connection'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      ref
                          .read(settingsProvider.notifier)
                          .updateEndpoint(_endpointController.text);
                      ref.invalidate(connectionStatusProvider);
                      ref.invalidate(availableModelsProvider);
                      if (settings.isHapticEnabled)
                        HapticFeedback.lightImpact();
                    }
                  },
                  child: const Text('Connect'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModelsSection(
    BuildContext context,
    dynamic settings,
    AsyncValue<List<OllamaModel>> modelsAsync,
  ) {
    return Column(
      children: [
        ListTile(
          title: const Text('Models'),
          trailing: IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(availableModelsProvider);
              if (settings.isHapticEnabled) HapticFeedback.lightImpact();
            },
          ),
        ),
        modelsAsync.when(
          data: (models) {
            if (models.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'No models found. Run "ollama pull <model>" in Termux.',
                ),
              );
            }
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: models.length,
              itemBuilder: (context, index) {
                final model = models[index];
                return RadioListTile<String>(
                  title: Row(
                    children: [
                      Text(model.name),
                      if (model.supportsVision) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.image, size: 16, color: Colors.blue),
                      ],
                    ],
                  ),
                  subtitle: Text(
                    model.size != null
                        ? '${(model.size! / 1024 / 1024 / 1024).toStringAsFixed(1)} GB'
                        : 'Unknown size',
                  ),
                  value: model.name,
                  groupValue:
                      settings.defaultModelId ??
                      (models.isNotEmpty ? models.first.name : null),
                  onChanged: (value) {
                    if (value != null) {
                      ref
                          .read(settingsProvider.notifier)
                          .setDefaultModel(value);
                      if (settings.isHapticEnabled)
                        HapticFeedback.selectionClick();
                    }
                  },
                  secondary: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () {
                      // Confirm delete
                      showDialog(
                        context: context,
                        builder:
                            (context) => AlertDialog(
                              title: Text('Delete ${model.name}?'),
                              content: const Text(
                                'This will remove the model from your device.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    Navigator.pop(context);
                                    await ref
                                        .read(availableModelsProvider.notifier)
                                        .deleteModel(model.name);
                                  },
                                  child: const Text(
                                    'Delete',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                      );
                    },
                  ),
                );
              },
            );
          },
          loading:
              () => const Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
          error:
              (e, _) => Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Error loading models: $e'),
              ),
        ),
      ],
    );
  }

  Widget _buildAppearanceSection(BuildContext context, dynamic settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Appearance',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        ListTile(
          title: const Text('Theme'),
          trailing: SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.light,
                icon: Icon(Icons.light_mode),
              ),
              ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode)),
              ButtonSegment(
                value: ThemeMode.system,
                icon: Icon(Icons.brightness_auto),
              ),
            ],
            selected: {settings.themeMode},
            onSelectionChanged: (Set<ThemeMode> newSelection) {
              ref
                  .read(settingsProvider.notifier)
                  .updateTheme(newSelection.first);
              if (settings.isHapticEnabled) HapticFeedback.selectionClick();
            },
          ),
        ),
        SwitchListTile(
          title: const Text('Haptic Feedback'),
          value: settings.isHapticEnabled,
          onChanged: (val) {
            ref.read(settingsProvider.notifier).toggleHaptic(val);
            if (val) HapticFeedback.lightImpact();
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Text('Font Size'),
              Expanded(
                child: Slider(
                  value: settings.fontSizeScale,
                  min: 0.8,
                  max: 1.4,
                  divisions: 6,
                  label: settings.fontSizeScale.toStringAsFixed(1),
                  onChanged: (val) {
                    ref.read(settingsProvider.notifier).updateFontSize(val);
                  },
                ),
              ),
              Text('x${settings.fontSizeScale.toStringAsFixed(1)}'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStorageSection(BuildContext context, dynamic settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Storage',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        SwitchListTile(
          title: const Text('Compress Images'),
          subtitle: const Text('Save space by compressing stored images'),
          value: settings.compressImages,
          onChanged:
              (val) =>
                  ref.read(settingsProvider.notifier).toggleCompressImages(val),
        ),
        ListTile(
          title: const Text(
            'Clear All History',
            style: TextStyle(color: Colors.red),
          ),
          onTap: () {
            showDialog(
              context: context,
              builder:
                  (context) => AlertDialog(
                    title: const Text('Clear All History?'),
                    content: const Text('This cannot be undone.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          await ref.read(chatRepositoryProvider).clearAll();
                          ref.read(chatHistoryProvider.notifier).refresh();
                          if (settings.isHapticEnabled)
                            HapticFeedback.mediumImpact();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('History Cleared')),
                            );
                          }
                        },
                        child: const Text(
                          'Clear',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAboutSection(BuildContext context) {
    return Column(
      children: [
        FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (context, snapshot) {
            final version = snapshot.data?.version ?? '...';
            return ListTile(
              title: const Text('App Version'),
              trailing: Text(version),
            );
          },
        ),
        ExpansionTile(
          title: const Text('FAQ & Help'),
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: MarkdownBody(
                data: '''
**How to use:**
1. Install Termux from F-Droid or GitHub.
2. In Termux, run: `pkg install ollama`
3. Start server: `ollama serve`
4. Pull a model: `ollama pull llama3` (keep Termux running!)

**Troubleshooting:**
- If "Connection Failed", make sure Termux is not battery optimized by Android.
- For Emulators, use `adb reverse`.
                 ''',
              ),
            ),
          ],
        ),
        ListTile(
          title: const Text('Privacy Policy'),
          onTap: () {
            // Show simple dialog or launch url
            showDialog(
              context: context,
              builder:
                  (context) => const AlertDialog(
                    title: Text('Privacy Policy'),
                    content: Text(
                      'Pocket LLM Lite is 100% offline. No data is sent to the cloud. Your chats are stored locally on your device.',
                    ),
                  ),
            );
          },
        ),
      ],
    );
  }
}
