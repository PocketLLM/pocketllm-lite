import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/providers.dart';
import '../../domain/models/file_item.dart';
import '../../../../features/chat/domain/models/chat_session.dart';

class FileGalleryScreen extends ConsumerStatefulWidget {
  const FileGalleryScreen({super.key});

  @override
  ConsumerState<FileGalleryScreen> createState() => _FileGalleryScreenState();
}

class _FileGalleryScreenState extends ConsumerState<FileGalleryScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<FileItem> _filterFiles(List<FileItem> files) {
    if (_searchQuery.isEmpty) return files;

    final query = _searchQuery.toLowerCase();
    return files.where((item) {
      return item.attachment.name.toLowerCase().contains(query) ||
             item.attachment.content.toLowerCase().contains(query) ||
             item.chatTitle.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _handleShare(FileItem item) async {
    try {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/${item.attachment.name}');
      await file.writeAsString(item.attachment.content);

      // ignore: deprecated_member_use
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Shared from PocketLLM Lite',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Share failed: $e')),
        );
      }
    }
  }

  void _showFilePreview(FileItem item) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.attachment.name,
                          style: Theme.of(context).textTheme.titleLarge,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'From: ${item.chatTitle}',
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
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
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: SelectableText(item.attachment.content),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _confirmDelete(item),
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    label: const Text('Delete', style: TextStyle(color: Colors.red)),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () {
                        // Share
                        _handleShare(item);
                    },
                    icon: const Icon(Icons.share),
                    label: const Text('Share'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(FileItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete File?'),
        content: Text('Are you sure you want to delete "${item.attachment.name}"? This will remove it from the chat.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
                final storage = ref.read(storageServiceProvider);
                await storage.deleteAttachment(item.chatId, item.message, item.attachment);
                if (mounted) {
                    Navigator.pop(context); // Close confirm
                    Navigator.pop(context); // Close preview
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('File deleted')),
                    );
                }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final storage = ref.watch(storageServiceProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('File Gallery'),
      ),
      body: Column(
        children: [
            Padding(
                padding: const EdgeInsets.all(16),
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
                            borderSide: BorderSide.none,
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
                  final allFiles = storage.getAllAttachments();
                  final filteredFiles = _filterFiles(allFiles);

                  if (allFiles.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.snippet_folder_outlined,
                            size: 64,
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No files attached yet',
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  if (filteredFiles.isEmpty) {
                    return const Center(
                      child: Text('No matching files found'),
                    );
                  }

                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: filteredFiles.length,
                    itemBuilder: (context, index) {
                      return _buildFileCard(context, filteredFiles[index]);
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFileCard(BuildContext context, FileItem item) {
    final theme = Theme.of(context);
    final ext = item.attachment.name.split('.').last.toUpperCase();
    final sizeKb = (item.attachment.sizeBytes / 1024).toStringAsFixed(1);

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showFilePreview(item),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.description_outlined, size: 32, color: theme.colorScheme.primary),
                      const SizedBox(height: 8),
                      Text(
                        ext,
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.attachment.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          DateFormat.yMMMd().format(item.message.timestamp),
                          style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${sizeKb}KB',
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
