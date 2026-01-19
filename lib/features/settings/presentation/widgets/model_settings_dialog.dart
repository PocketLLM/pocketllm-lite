import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers.dart';

class ModelSettingsDialog extends ConsumerStatefulWidget {
  final String modelName;

  const ModelSettingsDialog({
    super.key,
    required this.modelName,
  });

  @override
  ConsumerState<ModelSettingsDialog> createState() => _ModelSettingsDialogState();
}

class _ModelSettingsDialogState extends ConsumerState<ModelSettingsDialog> {
  late TextEditingController _systemPromptController;
  double _temperature = 0.7;
  double _topP = 0.9;
  int _topK = 40;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _systemPromptController = TextEditingController();
    _loadSettings();
  }

  @override
  void dispose() {
    _systemPromptController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final storage = ref.read(storageServiceProvider);
    final key = '${AppConstants.modelSettingsPrefixKey}${widget.modelName}';
    final settings = storage.getSetting(key);

    if (settings != null && settings is Map) {
      if (mounted) {
        setState(() {
          _systemPromptController.text = settings['systemPrompt'] ?? '';
          _temperature = (settings['temperature'] as num?)?.toDouble() ?? 0.7;
          _topP = (settings['topP'] as num?)?.toDouble() ?? 0.9;
          _topK = (settings['topK'] as num?)?.toInt() ?? 40;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    final storage = ref.read(storageServiceProvider);
    final key = '${AppConstants.modelSettingsPrefixKey}${widget.modelName}';

    final settings = {
      'systemPrompt': _systemPromptController.text,
      'temperature': _temperature,
      'topP': _topP,
      'topK': _topK,
    };

    await storage.saveSetting(key, settings);

    if (mounted) {
       HapticFeedback.mediumImpact();
       Navigator.of(context).pop();
       ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Settings saved for ${widget.modelName}')),
      );
    }
  }

  void _showPresetsDialog() {
    final storage = ref.read(storageServiceProvider);
    final presets = storage.getSystemPrompts();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select System Prompt'),
        content: SizedBox(
          width: double.maxFinite,
          child: presets.isEmpty
          ? const Text('No presets found. Create one in Settings > Prompts.')
          : ListView.builder(
            shrinkWrap: true,
            itemCount: presets.length,
            itemBuilder: (context, index) {
              final preset = presets[index];
              return ListTile(
                title: Text(preset.title),
                subtitle: Text(
                  preset.content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
                onTap: () {
                  setState(() {
                    _systemPromptController.text = preset.content;
                  });
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AlertDialog(
        content: SizedBox(
          height: 100,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return AlertDialog(
      title: Text('Settings: ${widget.modelName}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('System Prompt', style: TextStyle(fontWeight: FontWeight.bold)),
                TextButton(
                  onPressed: _showPresetsDialog,
                  child: const Text('Load Preset'),
                ),
              ],
            ),
            TextField(
              controller: _systemPromptController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Enter system prompt...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            ExpansionTile(
              title: const Text('Advanced Parameters'),
              childrenPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
              children: [
                // Temperature
                Row(
                  children: [
                    const Text('Temperature'),
                    const Spacer(),
                    Text(_temperature.toStringAsFixed(1)),
                  ],
                ),
                Slider(
                  value: _temperature,
                  min: 0.0,
                  max: 1.0,
                  divisions: 10,
                  label: _temperature.toStringAsFixed(1),
                  onChanged: (val) => setState(() => _temperature = val),
                ),
                const Text(
                  'Higher values make output more random/creative.',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(height: 12),

                // Top P
                Row(
                  children: [
                    const Text('Top P'),
                    const Spacer(),
                    Text(_topP.toStringAsFixed(1)),
                  ],
                ),
                Slider(
                  value: _topP,
                  min: 0.0,
                  max: 1.0,
                  divisions: 10,
                  label: _topP.toStringAsFixed(1),
                  onChanged: (val) => setState(() => _topP = val),
                ),
                const Text(
                  'Controls diversity via nucleus sampling.',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(height: 12),

                // Top K
                Row(
                  children: [
                    const Text('Top K'),
                    const Spacer(),
                    Text(_topK.toString()),
                  ],
                ),
                Slider(
                  value: _topK.toDouble(),
                  min: 1,
                  max: 100,
                  divisions: 99,
                  label: _topK.toString(),
                  onChanged: (val) => setState(() => _topK = val.toInt()),
                ),
                const Text(
                  'Limits the next token selection to K most likely tokens.',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saveSettings,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
