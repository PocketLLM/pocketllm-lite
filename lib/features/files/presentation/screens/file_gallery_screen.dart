import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers.dart';
import '../../../../features/chat/domain/models/chat_session.dart';
import '../../../../features/files/domain/models/file_item.dart';

class FileGalleryScreen extends ConsumerStatefulWidget {
  const FileGalleryScreen({super.key});

  @override
  ConsumerState<FileGalleryScreen> createState() => _FileGalleryScreenState();
}

enum FileSortOption { dateDesc, dateAsc, nameAsc, nameDesc, sizeDesc, sizeAsc }

class _FileGalleryScreenState extends ConsumerState<FileGalleryScreen> {
  String _searchQuery = '';
  FileSortOption _sortOption = FileSortOption.dateDesc;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<FileItem> _processFiles(List<FileItem> files) {
    // 1. Filter
    var filtered = files;
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = files.where((item) {
        return item.attachment.name.toLowerCase().contains(query);
      }).toList();
    }

    // 2. Sort
    filtered.sort((a, b) {
      switch (_sortOption) {
        case FileSortOption.dateDesc:
          return b.uploadedAt.compareTo(a.uploadedAt);
        case FileSortOption.dateAsc:
          return a.uploadedAt.compareTo(b.uploadedAt);
        case FileSortOption.nameAsc:
          return a.attachment.name.compareTo(b.attachment.name);
        case FileSortOption.nameDesc:
          return b.attachment.name.compareTo(a.attachment.name);
        case FileSortOption.sizeDesc:
          return b.attachment.sizeBytes.compareTo(a.attachment.sizeBytes);
        case FileSortOption.sizeAsc:
          return a.attachment.sizeBytes.compareTo(b.attachment.sizeBytes);
      }
    });

    return filtered;
  }

  Future<void> _handleDelete(FileItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete File?'),
        content: Text(
          'Are you sure you want to delete "${item.attachment.name}"? This will remove it from the chat message.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final storage = ref.read(storageServiceProvider);
      await storage.deleteAttachment(
        item.chatId,
        item.uploadedAt,
        item.attachment,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('File deleted')));
      }
    }
  }

  void _showFilePreview(FileItem item) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.attachment.name,
                      style: Theme.of(context).textTheme.titleLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: SelectableText(item.attachment.content),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(text: item.attachment.content),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied to clipboard')),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copy Content'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final storage = ref.watch(storageServiceProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('File Gallery'),
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
        actions: [
          PopupMenuButton<FileSortOption>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort by',
            initialValue: _sortOption,
            onSelected: (val) => setState(() => _sortOption = val),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: FileSortOption.dateDesc,
                child: Text('Newest First'),
              ),
              const PopupMenuItem(
                value: FileSortOption.dateAsc,
                child: Text('Oldest First'),
              ),
              const PopupMenuItem(
                value: FileSortOption.nameAsc,
                child: Text('Name (A-Z)'),
              ),
              const PopupMenuItem(
                value: FileSortOption.nameDesc,
                child: Text('Name (Z-A)'),
              ),
              const PopupMenuItem(
                value: FileSortOption.sizeDesc,
                child: Text('Size (Largest)'),
              ),
              const PopupMenuItem(
                value: FileSortOption.sizeAsc,
                child: Text('Size (Smallest)'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search files...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          Expanded(
            child: ValueListenableBuilder<Box<ChatSession>>(
              valueListenable: storage.chatBoxListenable,
              builder: (context, box, _) {
                final allFiles = storage.getAllTextAttachments();
                final processedFiles = _processFiles(allFiles);

                if (processedFiles.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.insert_drive_file_outlined,
                          size: 64,
                          color: theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty
                              ? 'No text files found'
                              : 'No matching files found',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: processedFiles.length,
                  itemBuilder: (context, index) {
                    final item = processedFiles[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Icon(
                          Icons.description,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                      title: Text(
                        item.attachment.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        '${DateFormat('MMM d, y • HH:mm').format(item.uploadedAt)} • ${_formatSize(item.attachment.sizeBytes)}',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _handleDelete(item),
                      ),
                      onTap: () => _showFilePreview(item),
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
}
