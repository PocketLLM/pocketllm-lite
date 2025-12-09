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
      appBar: AppBar(title: const Text('System Prompts')),
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
              return ListTile(
                title: Text(
                  prompt.title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  prompt.content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => _showEditDialog(context, storage, prompt),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => storage.deleteSystemPrompt(prompt.id),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          HapticFeedback.lightImpact();
          _showEditDialog(context, storage, null);
        },
        child: const Icon(Icons.add),
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
      builder: (context) => AlertDialog(
        title: Text(prompt == null ? 'New Prompt' : 'Edit Prompt'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'e.g. Coding Assistant',
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: contentCtrl,
              decoration: const InputDecoration(
                labelText: 'System Prompt Content',
                hintText: 'You are a helpful...',
              ),
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (titleCtrl.text.isEmpty || contentCtrl.text.isEmpty) return;

              HapticFeedback.mediumImpact();

              final newPrompt = SystemPrompt(
                id: prompt?.id ?? const Uuid().v4(),
                title: titleCtrl.text.trim(),
                content: contentCtrl.text.trim(),
              );

              await storage.saveSystemPrompt(newPrompt);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
