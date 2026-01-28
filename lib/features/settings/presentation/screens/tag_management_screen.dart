import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers.dart';
import '../../../../services/storage_service.dart';

class TagManagementScreen extends ConsumerStatefulWidget {
  const TagManagementScreen({super.key});

  @override
  ConsumerState<TagManagementScreen> createState() =>
      _TagManagementScreenState();
}

class _TagManagementScreenState extends ConsumerState<TagManagementScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

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
      appBar: AppBar(title: const Text('Manage Tags')),
      body: ValueListenableBuilder(
        valueListenable: storage.settingsBoxListenable,
        builder: (context, box, _) {
          final allTags = storage.getAllTags().toList()..sort();
          final filteredTags =
              allTags.where((tag) {
                return tag.toLowerCase().contains(_searchQuery.toLowerCase());
              }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search tags...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.3),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    suffixIcon:
                        _searchQuery.isNotEmpty
                            ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                            : null,
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              ),
              Expanded(
                child:
                    filteredTags.isEmpty
                        ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.label_off_outlined,
                                size: 64,
                                color: theme.colorScheme.outline,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'No tags matching "$_searchQuery"'
                                    : 'No tags found',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        )
                        : ListView.separated(
                          itemCount: filteredTags.length,
                          separatorBuilder:
                              (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final tag = filteredTags[index];
                            return ListTile(
                              leading: const Icon(Icons.label_outlined),
                              title: Text(tag),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined),
                                    tooltip: 'Rename',
                                    onPressed:
                                        () => _showRenameDialog(
                                          context,
                                          storage,
                                          tag,
                                        ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.delete_outline,
                                      color: theme.colorScheme.error,
                                    ),
                                    tooltip: 'Delete',
                                    onPressed:
                                        () => _showDeleteDialog(
                                          context,
                                          storage,
                                          tag,
                                        ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showRenameDialog(
    BuildContext context,
    StorageService storage,
    String oldTag,
  ) async {
    final controller = TextEditingController(text: oldTag);
    final theme = Theme.of(context);

    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Rename Tag'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'Tag Name',
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 8),
                Text(
                  'This will update the tag in all chats.',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
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
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Renamed "$oldTag" to "$newTag"'),
                        ),
                      );
                    }
                  }
                },
                child: const Text('Rename'),
              ),
            ],
          ),
    );
  }

  Future<void> _showDeleteDialog(
    BuildContext context,
    StorageService storage,
    String tag,
  ) async {
    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Tag?'),
            content: Text(
              'Are you sure you want to delete the tag "$tag"?\n\nThis will remove it from all chats.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                onPressed: () async {
                  await storage.deleteTag(tag);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Deleted tag "$tag"')),
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
