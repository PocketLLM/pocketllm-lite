import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../../core/providers.dart';
import '../../../../services/storage_service.dart';

class TagManagementScreen extends ConsumerStatefulWidget {
  const TagManagementScreen({super.key});

  @override
  ConsumerState<TagManagementScreen> createState() => _TagManagementScreenState();
}

class _TagManagementScreenState extends ConsumerState<TagManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search tags...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
              onChanged: (val) {
                setState(() => _searchQuery = val);
              },
            ),
          ),
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: storage.settingsBoxListenable,
              builder: (context, box, _) {
                // We rely on getAllTags which reads from cache/box
                // Rebuilds whenever settings change (including tags)
                final tagsMap = storage.getChatTagsMap();
                final allTags = <String>{};
                final tagCounts = <String, int>{};

                for (final entry in tagsMap.entries) {
                  for (final tag in entry.value) {
                    allTags.add(tag);
                    tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
                  }
                }

                final sortedTags = allTags.toList()..sort();
                final filteredTags = sortedTags.where((tag) {
                  return tag.toLowerCase().contains(_searchQuery.toLowerCase());
                }).toList();

                if (allTags.isEmpty) {
                   return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.label_outline, size: 64, color: theme.colorScheme.outline.withValues(alpha: 0.5)),
                        const SizedBox(height: 16),
                        Text(
                          'No tags yet',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add tags to your chats to organize them',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                   );
                }

                if (filteredTags.isEmpty) {
                   return const Center(child: Text('No tags match your search'));
                }

                return ListView.builder(
                  itemCount: filteredTags.length,
                  itemBuilder: (context, index) {
                    final tag = filteredTags[index];
                    final count = tagCounts[tag] ?? 0;

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: theme.colorScheme.secondaryContainer,
                        child: Icon(Icons.label, color: theme.colorScheme.onSecondaryContainer, size: 20),
                      ),
                      title: Text(tag, style: const TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: Text('$count ${count == 1 ? 'chat' : 'chats'}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            tooltip: 'Rename',
                            onPressed: () => _showRenameDialog(context, storage, tag),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            tooltip: 'Delete',
                            onPressed: () => _showDeleteDialog(context, storage, tag, count),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(BuildContext context, StorageService storage, String oldTag) {
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
                if (context.mounted) {
                  HapticFeedback.mediumImpact();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Renamed tag to "$newTag"')),
                  );
                }
              } else {
                 Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, StorageService storage, String tag, int count) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Tag?'),
        content: Text(
          'Are you sure you want to delete the tag "$tag"?\n\n'
          'It will be removed from $count ${count == 1 ? 'chat' : 'chats'}.',
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
              if (context.mounted) {
                 HapticFeedback.mediumImpact();
                 Navigator.pop(context);
                 ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Tag deleted')),
                 );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
