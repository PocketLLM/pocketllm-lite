import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../services/storage_service.dart';
import '../../../../core/providers.dart';
import '../providers/chat_provider.dart';

class ChatSettingsDialog extends ConsumerStatefulWidget {
  const ChatSettingsDialog({super.key});

  @override
  ConsumerState<ChatSettingsDialog> createState() => _ChatSettingsDialogState();
}

class _ChatSettingsDialogState extends ConsumerState<ChatSettingsDialog> {
  double _temp = 0.7;
  double _topP = 0.9;
  String? _selectedSystemPromptId;

  @override
  void initState() {
    super.initState();
    final state = ref.read(chatProvider);
    _temp = state.temperature;
    _topP = state.topP;

    // We don't store prompt ID in chat state, just string content.
    // So we can't easily pre-select the dropbox unless we search content match.
    // For now, let's just allow selecting "None" or one from list to Apply content.
  }

  @override
  Widget build(BuildContext context) {
    final storage = ref.watch(storageServiceProvider);

    return AlertDialog(
      title: const Text('Chat Settings'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'System Prompt',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder(
              valueListenable: storage.promptBoxListenable,
              builder: (context, box, _) {
                final prompts = box.values.toList();
                return DropdownButtonFormField<String?>(
                  value: _selectedSystemPromptId,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12),
                  ),
                  hint: const Text('Select a prompt template...'),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('None (Default)'),
                    ),
                    ...prompts.map(
                      (p) =>
                          DropdownMenuItem(value: p.id, child: Text(p.title)),
                    ),
                  ],
                  onChanged: (val) {
                    setState(() => _selectedSystemPromptId = val);
                  },
                );
              },
            ),
            if (_selectedSystemPromptId != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Applying this will set the system prompt context for this chat.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ),

            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Temperature',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(_temp.toStringAsFixed(1)),
              ],
            ),
            Slider(
              value: _temp,
              min: 0.0,
              max: 2.0,
              divisions: 20,
              label: _temp.toStringAsFixed(1),
              onChanged: (val) => setState(() => _temp = val),
            ),
            const Text(
              'Controls randomness. Higher = more creative.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),

            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Top P',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
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
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            String? promptContent;
            if (_selectedSystemPromptId != null) {
              final storage = ref.read(storageServiceProvider);
              // We need to fetch it. Since we are inside Consumer, we can't easily get it synchronously
              // from listenable without looking at box directly which is fine since we passed it in build.
              // But easier is just to use storage methods if we added getSystemPrompt(id).
              // We didn't add getSystemPrompt(id) to StorageService.
              // Let's iterate box values from listenable or just trust the list we saw.
              final box = storage
                  .promptBoxListenable
                  .value; // Access the box safely? No, listenable.value is box.
              final prompt = box.values.firstWhere(
                (p) => p.id == _selectedSystemPromptId,
              );
              promptContent = prompt.content;
            }

            ref
                .read(chatProvider.notifier)
                .updateSettings(
                  temperature: _temp,
                  topP: _topP,
                  systemPrompt: promptContent,
                );

            Navigator.pop(context);
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
