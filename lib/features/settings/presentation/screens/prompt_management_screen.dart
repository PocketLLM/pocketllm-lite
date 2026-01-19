import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers.dart';
import '../../../../services/storage_service.dart';
import '../../../chat/domain/models/system_prompt.dart';

class PromptManagementScreen extends ConsumerWidget {
  const PromptManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(storageServiceProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        // Use GoRouter's pop method instead of Navigator.pop to avoid stack issues
        if (GoRouter.of(context).canPop()) {
          context.pop();
        } else {
          // If we can't pop, go to the settings screen directly
          context.go('/settings');
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('System Prompts Library'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              // Use GoRouter's pop method instead of Navigator.pop to avoid stack issues
              if (GoRouter.of(context).canPop()) {
                context.pop();
              } else {
                // If we can't pop, go to the settings screen directly
                context.go('/settings');
              }
            },
          ),
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
                    ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
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
                          ).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
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
              RichText(
                text: TextSpan(
                  text: 'Prompt Title',
                  style: DefaultTextStyle.of(
                    context,
                  ).style.copyWith(fontWeight: FontWeight.w500),
                  children: const [
                    TextSpan(
                      text: ' *',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: titleCtrl,
                autofocus: prompt == null,
                textInputAction: TextInputAction.next,
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
              RichText(
                text: TextSpan(
                  text: 'Prompt Content',
                  style: DefaultTextStyle.of(
                    context,
                  ).style.copyWith(fontWeight: FontWeight.w500),
                  children: const [
                    TextSpan(
                      text: ' *',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: contentCtrl,
                textInputAction: TextInputAction.newline,
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
                mainAxisAlignment: prompt != null
                    ? MainAxisAlignment.spaceBetween
                    : MainAxisAlignment.end,
                children: [
                  if (prompt != null)
                    TextButton.icon(
                      onPressed: () => _confirmDelete(context, storage, prompt),
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      label: const Text(
                        'Delete',
                        style: TextStyle(color: Colors.red),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () {
                          // Use GoRouter's pop method instead of Navigator.pop to avoid stack issues
                          if (GoRouter.of(context).canPop()) {
                            Navigator.pop(context);
                          } else {
                            // If we can't pop, go to the settings screen directly
                            context.go('/settings');
                          }
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: Colors.grey.withValues(alpha: 0.2),
                            ),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      AnimatedBuilder(
                        animation: Listenable.merge([titleCtrl, contentCtrl]),
                        builder: (context, child) {
                          final isValid =
                              titleCtrl.text.trim().isNotEmpty &&
                              contentCtrl.text.trim().isNotEmpty;
                          return ElevatedButton(
                            onPressed:
                                isValid
                                    ? () async {
                                      HapticFeedback.mediumImpact();
                                      final newPrompt = SystemPrompt(
                                        id: prompt?.id ?? const Uuid().v4(),
                                        title: titleCtrl.text.trim(),
                                        content: contentCtrl.text.trim(),
                                      );
                                      await storage.saveSystemPrompt(newPrompt);
                                      if (context.mounted) {
                                        // Use GoRouter's pop method instead of Navigator.pop to avoid stack issues
                                        if (GoRouter.of(context).canPop()) {
                                          Navigator.pop(context);
                                        } else {
                                          // If we can't pop, go to the settings screen directly
                                          context.go('/settings');
                                        }
                                      }
                                    }
                                    : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey[300],
                              disabledForegroundColor: Colors.grey[600],
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Save'),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    StorageService storage,
    SystemPrompt prompt,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete System Prompt?'),
        content: Text('Are you sure you want to delete "${prompt.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              HapticFeedback.mediumImpact();
              await storage.deleteSystemPrompt(prompt.id);
              if (context.mounted) {
                // Pop confirmation dialog
                Navigator.pop(dialogContext);
                // Pop edit dialog safely
                if (GoRouter.of(context).canPop()) {
                  Navigator.pop(context);
                } else {
                  context.go('/settings');
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}