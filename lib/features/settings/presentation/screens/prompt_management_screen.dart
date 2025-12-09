import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/providers.dart';
import '../../../../services/storage_service.dart';
import '../../../chat/domain/models/system_prompt.dart';

class PromptManagementScreen extends ConsumerWidget {
  const PromptManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(storageServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('System Prompts Library'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              HapticFeedback.lightImpact();
              _showEditDialog(context, storage, null);
            },
          ),
        ],
      ),
      body: ValueListenableBuilder<Box<SystemPrompt>>(
        valueListenable: storage.promptBoxListenable,
        builder: (context, box, _) {
          final prompts = box.values.toList();

          if (prompts.isEmpty) {
            return const Center(child: Text('No saved prompts. Add one!'));
          }

          return ListView.builder(
            itemCount: prompts.length,
            itemBuilder: (context, index) {
              final prompt = prompts[index];
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).dividerColor.withOpacity(0.1),
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  title: Text(
                    prompt.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      prompt.content,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.color?.withOpacity(0.7),
                      ),
                    ),
                  ),
                  onTap: () => _showEditDialog(context, storage, prompt),
                  // trailing: IconButton(
                  //   icon: const Icon(Icons.delete_outline),
                  //   onPressed: () => storage.deleteSystemPrompt(prompt.id),
                  // ), // Removed trailing logic to match image, or maybe specific edit flow? The request says "list of cards".
                  // Let's keep it clean as per image which shows cards. Maybe edit/delete inside dialog?
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showEditDialog(
    BuildContext context,
    StorageService storage,
    SystemPrompt? prompt,
  ) {
    final titleCtrl = TextEditingController(text: prompt?.title ?? '');
    final contentCtrl = TextEditingController(text: prompt?.content ?? '');

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                prompt == null
                    ? 'Create New System Prompt'
                    : 'Edit System Prompt',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Prompt Title',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: titleCtrl,
                decoration: InputDecoration(
                  hintText: 'e.g., Creative Writer',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 16),
              const Text(
                'Prompt Content',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: contentCtrl,
                decoration: InputDecoration(
                  hintText: 'Enter the detailed instructions for the AI...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.grey.withOpacity(0.2)),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () async {
                      if (titleCtrl.text.isEmpty || contentCtrl.text.isEmpty) {
                        return;
                      }
                      HapticFeedback.mediumImpact();
                      final newPrompt = SystemPrompt(
                        id: prompt?.id ?? const Uuid().v4(),
                        title: titleCtrl.text.trim(),
                        content: contentCtrl.text.trim(),
                      );
                      await storage.saveSystemPrompt(newPrompt);
                      if (context.mounted) Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Save'),
                  ),
                ],
              ),
              if (prompt != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Center(
                    child: TextButton.icon(
                      onPressed: () async {
                        await storage.deleteSystemPrompt(prompt.id);
                        if (context.mounted) Navigator.pop(context);
                      },
                      icon: const Icon(
                        Icons.delete,
                        color: Colors.red,
                        size: 18,
                      ),
                      label: const Text(
                        'Delete Prompt',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
