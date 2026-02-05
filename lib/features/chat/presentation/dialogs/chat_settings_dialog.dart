import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
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
  int _topK = AppConstants.defaultTopK;
  int _numCtx = AppConstants.defaultNumCtx;
  double _repeatPenalty = AppConstants.defaultRepeatPenalty;
  int? _seed;
  String? _selectedSystemPromptId;

  // Controller for Seed
  late TextEditingController _seedController;

  @override
  void initState() {
    super.initState();
    final state = ref.read(chatProvider);
    _temp = state.temperature;
    _topP = state.topP;
    _topK = state.topK;
    _numCtx = state.numCtx;
    _repeatPenalty = state.repeatPenalty;
    _seed = state.seed;
    _seedController = TextEditingController(text: _seed?.toString() ?? '');

    // We don't store prompt ID in chat state, just string content.
    // So we can't easily pre-select the dropbox unless we search content match.
    // For now, let's just allow selecting "None" or one from list to Apply content.
  }

  @override
  void dispose() {
    _seedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final storage = ref.watch(storageServiceProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[700];

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
                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[800]
                        : Colors.white,
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[700]!
                          : Colors.grey[300]!,
                    ),
                  ),
                  child: DropdownButtonFormField<String?>(
                    initialValue: _selectedSystemPromptId,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    isExpanded: true,
                    icon: const Icon(Icons.arrow_drop_down, size: 24),
                    hint: const Text('Select a prompt template...'),
                    dropdownColor:
                        Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[800]
                        : Colors.white,
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black,
                      fontSize: 16,
                    ),
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text(
                          'None (Default)',
                          style: TextStyle(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : Colors.black,
                          ),
                        ),
                      ),
                      ...prompts.map(
                        (p) => DropdownMenuItem(
                          value: p.id,
                          child: Text(
                            p.title,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white
                                  : Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      setState(() => _selectedSystemPromptId = val);
                    },
                  ),
                );
              },
            ),
            if (_selectedSystemPromptId != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Applying this will set the system prompt context for this chat.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[400]
                        : Colors.grey[700],
                  ),
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
                Text(
                  _temp.toStringAsFixed(1),
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black,
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
              activeColor: Colors.blue,
              inactiveColor: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[700]
                  : Colors.grey[300],
              onChanged: (val) {
                setState(() => _temp = val);
              },
            ),
            Text(
              'Controls randomness. Higher = more creative.',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[400]
                    : Colors.grey[700],
              ),
            ),

            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Top P',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  _topP.toStringAsFixed(1),
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black,
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
              activeColor: Colors.blue,
              inactiveColor: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[700]
                  : Colors.grey[300],
              onChanged: (val) {
                setState(() => _topP = val);
              },
            ),
            Text(
              'Controls diversity via nucleus sampling.',
              style: TextStyle(
                fontSize: 12,
                color: subTextColor,
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                title: const Text(
                  'Advanced Parameters',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                tilePadding: EdgeInsets.zero,
                children: [
                  // Context Window (num_ctx)
                  const SizedBox(height: 8),
                  const Text('Context Window Size', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<int>(
                    value: _numCtx,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    items: [2048, 4096, 8192, 16384, 32768].map((size) {
                      return DropdownMenuItem(
                        value: size,
                        child: Text(size.toString()),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _numCtx = val);
                    },
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tokens to process at once. Higher uses more RAM.',
                    style: TextStyle(fontSize: 11, color: subTextColor),
                  ),
                  const SizedBox(height: 16),

                  // Top K
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Top K', style: TextStyle(fontWeight: FontWeight.w500)),
                      Text(_topK.toString(), style: TextStyle(color: textColor)),
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
                  Text(
                    'Limits selection to K most likely tokens.',
                    style: TextStyle(fontSize: 11, color: subTextColor),
                  ),
                  const SizedBox(height: 16),

                  // Repeat Penalty
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Repeat Penalty', style: TextStyle(fontWeight: FontWeight.w500)),
                      Text(_repeatPenalty.toStringAsFixed(1), style: TextStyle(color: textColor)),
                    ],
                  ),
                  Slider(
                    value: _repeatPenalty,
                    min: 0.0,
                    max: 2.0,
                    divisions: 20,
                    label: _repeatPenalty.toStringAsFixed(1),
                    onChanged: (val) => setState(() => _repeatPenalty = val),
                  ),
                  Text(
                    'Penalizes repetitive text. Default: 1.1',
                    style: TextStyle(fontSize: 11, color: subTextColor),
                  ),
                  const SizedBox(height: 16),

                  // Seed
                  const Text('Seed (Optional)', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _seedController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      hintText: 'Random',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    onChanged: (val) {
                      if (val.isEmpty) {
                        _seed = null;
                      } else {
                        _seed = int.tryParse(val);
                      }
                    },
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Set for reproducible outputs.',
                    style: TextStyle(fontSize: 11, color: subTextColor),
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
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
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
                  topK: _topK,
                  numCtx: _numCtx,
                  repeatPenalty: _repeatPenalty,
                  seed: _seed,
                  systemPrompt: promptContent,
                );

            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            'Apply Changes',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
