import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: Text(
        'Chat Settings',
        style: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'System Prompt',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder(
              valueListenable: storage.promptBoxListenable,
              builder: (context, box, _) {
                final prompts = box.values.toList();
                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.3,
                    ),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: DropdownButtonFormField<String?>(
                    initialValue: _selectedSystemPromptId,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    isExpanded: true,
                    icon: Icon(
                      Icons.arrow_drop_down,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    hint: Text(
                      'Select a prompt template...',
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                    dropdownColor: colorScheme.surfaceContainerHigh,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text(
                          'None (Default)',
                          style: TextStyle(
                            color: colorScheme.onSurface.withValues(alpha: 0.7),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                      ...prompts.map(
                        (p) => DropdownMenuItem(
                          value: p.id,
                          child: Text(
                            p.title,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: colorScheme.onSurface),
                          ),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedSystemPromptId = val);
                    },
                  ),
                );
              },
            ),
            if (_selectedSystemPromptId != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0, left: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 14,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This will override the current system prompt context.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Temperature',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _temp.toStringAsFixed(1),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            Slider(
              value: _temp,
              min: 0.0,
              max: 2.0,
              divisions: 20,
              label: _temp.toStringAsFixed(1),
              activeColor: colorScheme.primary,
              inactiveColor: colorScheme.surfaceContainerHighest,
              onChanged: (val) {
                if ((val * 10).round() % 2 == 0)
                  HapticFeedback.selectionClick();
                setState(() => _temp = val);
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                'Controls randomness. Higher = more creative.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Top P',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _topP.toStringAsFixed(1),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            Slider(
              value: _topP,
              min: 0.0,
              max: 1.0,
              divisions: 10,
              label: _topP.toStringAsFixed(1),
              activeColor: colorScheme.primary,
              inactiveColor: colorScheme.surfaceContainerHighest,
              onChanged: (val) {
                HapticFeedback.selectionClick();
                setState(() => _topP = val);
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                'Controls diversity via nucleus sampling.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.tonal(
          onPressed: () {
            HapticFeedback.mediumImpact();
            final storage = ref.read(storageServiceProvider);

            String? promptContent;
            if (_selectedSystemPromptId != null) {
              final box = storage.promptBoxListenable.value;
              try {
                final prompt = box.values.firstWhere(
                  (p) => p.id == _selectedSystemPromptId,
                );
                promptContent = prompt.content;
              } catch (_) {}
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
          child: const Text('Apply Changes'),
        ),
      ],
    );
  }
}
