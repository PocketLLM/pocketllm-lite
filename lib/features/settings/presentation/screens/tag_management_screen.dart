import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers.dart';
import '../../../../services/storage_service.dart';

class TagManagementScreen extends ConsumerWidget {
  const TagManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(storageServiceProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Tags'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (GoRouter.of(context).canPop()) {
              context.pop();
            } else {
              context.go('/settings');
            }
          },
        ),
      ),
      body: ValueListenableBuilder(
        valueListenable: storage.settingsBoxListenable,
        builder: (context, box, _) {
          final tags = storage.getAllTags().toList()..sort();

          if (tags.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.label_outline,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No tags created yet',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add tags to your chats to organize them',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: tags.length,
            itemBuilder: (context, index) {
              final tag = tags[index];
              final count = storage.getChatCountForTag(tag);

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: theme.colorScheme.secondaryContainer,
                  child: Icon(
                    Icons.label,
                    color: theme.colorScheme.onSecondaryContainer,
                    size: 20,
                  ),
                ),
                title: Text(tag),
                subtitle: Text('$count chats'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showRenameDialog(context, storage, tag),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                      onPressed: () => _showDeleteDialog(context, storage, tag),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showRenameDialog(
    BuildContext context,
    StorageService storage,
    String oldTag,
  ) {
    final controller = TextEditingController(text: oldTag);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Tag'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Tag Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final newTag = controller.text.trim();
              if (newTag.isNotEmpty && newTag != oldTag) {
                await storage.renameTag(oldTag, newTag);
                HapticFeedback.mediumImpact();
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(
    BuildContext context,
    StorageService storage,
    String tag,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Tag?'),
        content: Text(
          'Are you sure you want to delete the tag "$tag"? This will remove it from all chats.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await storage.deleteTag(tag);
              HapticFeedback.heavyImpact();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
