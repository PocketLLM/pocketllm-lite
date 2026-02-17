import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers.dart';
import '../../../../core/widgets/m3_app_bar.dart';

class TagManagementScreen extends ConsumerStatefulWidget {
  const TagManagementScreen({super.key});

  @override
  ConsumerState<TagManagementScreen> createState() =>
      _TagManagementScreenState();
}

class _TagManagementScreenState extends ConsumerState<TagManagementScreen> {
  void _showRenameDialog(String tag) {
    final controller = TextEditingController(text: tag);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Tag'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'New tag name',
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
              if (newTag.isEmpty || newTag == tag) return;
              await ref.read(storageServiceProvider).renameTag(tag, newTag);
              if (!context.mounted) return;
              HapticFeedback.selectionClick();
              Navigator.pop(context);
              if (mounted) setState(() {});
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(String tag) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Tag'),
        content: Text('Remove "$tag" from all chats?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(storageServiceProvider).deleteTag(tag);
              if (!context.mounted) return;
              HapticFeedback.mediumImpact();
              Navigator.pop(context);
              if (mounted) setState(() {});
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(
              'Delete',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final storage = ref.watch(storageServiceProvider);
    final counts = storage.getTagUsageCounts();
    final tags = counts.keys.toList()..sort();

    return Scaffold(
      appBar: M3AppBar(
        title: 'Tag Management',
        onBack: () => Navigator.pop(context),
      ),
      body: tags.isEmpty
          ? Center(
              child: Text(
                'No tags yet.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          : ListView.separated(
              itemCount: tags.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final tag = tags[index];
                final count = counts[tag] ?? 0;
                return ListTile(
                  leading: const Icon(Icons.label),
                  title: Text(tag),
                  subtitle: Text('$count chats'),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'rename') {
                        _showRenameDialog(tag);
                      } else if (value == 'delete') {
                        _showDeleteDialog(tag);
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'rename', child: Text('Rename')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
