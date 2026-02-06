import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers.dart';
import '../../../chat/domain/models/chat_session.dart';
import '../../domain/models/file_item.dart';

enum FileSortOption { dateDesc, dateAsc, nameAsc, sizeDesc, sizeAsc }

class FileGalleryScreen extends ConsumerStatefulWidget {
  const FileGalleryScreen({super.key});

  @override
  ConsumerState<FileGalleryScreen> createState() => _FileGalleryScreenState();
}

class _FileGalleryScreenState extends ConsumerState<FileGalleryScreen> {
  String _searchQuery = '';
  FileSortOption _sortOption = FileSortOption.dateDesc;
  bool _isSearching = false;
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
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search files...',
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              )
            : const Text('File Gallery'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
             if (_isSearching) {
               setState(() {
                 _isSearching = false;
                 _searchQuery = '';
                 _searchController.clear();
               });
               return;
             }
             if (GoRouter.of(context).canPop()) {
               context.pop();
             } else {
               context.go('/settings');
             }
          },
        ),
        actions: [
          if (!_isSearching)
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                setState(() {
                  _isSearching = true;
                });
              },
            ),
          PopupMenuButton<FileSortOption>(
            icon: const Icon(Icons.sort),
            onSelected: (option) {
              setState(() {
                _sortOption = option;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: FileSortOption.dateDesc,
                child: Text('Date (Newest)'),
              ),
              const PopupMenuItem(
                value: FileSortOption.dateAsc,
                child: Text('Date (Oldest)'),
              ),
              const PopupMenuItem(
                value: FileSortOption.nameAsc,
                child: Text('Name (A-Z)'),
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
      body: ValueListenableBuilder<Box<ChatSession>>(
        valueListenable: storage.chatBoxListenable,
        builder: (context, box, _) {
          // Aggregate files
          final sessions = storage.getChatSessions();
          final List<FileItem> allFiles = [];

          for (final session in sessions) {
            for (final message in session.messages) {
              if (message.attachments != null && message.attachments!.isNotEmpty) {
                for (final attachment in message.attachments!) {
                  allFiles.add(
                    FileItem(
                      attachment: attachment,
                      chatId: session.id,
                      chatTitle: session.title,
                      message: message,
                    ),
                  );
                }
              }
            }
          }

          // Filter
          var filteredFiles = allFiles;
          if (_searchQuery.isNotEmpty) {
            final query = _searchQuery.toLowerCase();
            filteredFiles = allFiles.where((item) {
              return item.attachment.name.toLowerCase().contains(query) ||
                  item.attachment.content.toLowerCase().contains(query) ||
                  item.chatTitle.toLowerCase().contains(query);
            }).toList();
          }

          // Sort
          filteredFiles.sort((a, b) {
            switch (_sortOption) {
              case FileSortOption.dateDesc:
                return b.timestamp.compareTo(a.timestamp);
              case FileSortOption.dateAsc:
                return a.timestamp.compareTo(b.timestamp);
              case FileSortOption.nameAsc:
                return a.attachment.name.toLowerCase().compareTo(b.attachment.name.toLowerCase());
              case FileSortOption.sizeDesc:
                return b.attachment.sizeBytes.compareTo(a.attachment.sizeBytes);
              case FileSortOption.sizeAsc:
                return a.attachment.sizeBytes.compareTo(b.attachment.sizeBytes);
            }
          });

          if (filteredFiles.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _searchQuery.isNotEmpty ? 'No matching files found' : 'No files found',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: filteredFiles.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = filteredFiles[index];
              return ListTile(
                leading: _buildFileIcon(item.attachment.name, theme),
                title: Text(item.attachment.name, overflow: TextOverflow.ellipsis),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_formatSize(item.attachment.sizeBytes)} • ${DateFormat.yMMMd().format(item.timestamp)}',
                      style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                    ),
                    Text(
                      'in ${item.chatTitle}',
                      style: TextStyle(fontSize: 12, color: theme.colorScheme.primary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.visibility_outlined),
                      onPressed: () => _viewFile(context, item),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                      onPressed: () => _confirmDelete(context, item),
                    ),
                  ],
                ),
                onTap: () => _viewFile(context, item),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildFileIcon(String fileName, ThemeData theme) {
    IconData icon = Icons.insert_drive_file;
    final ext = fileName.split('.').last.toLowerCase();
    Color color = theme.colorScheme.onSurfaceVariant;

    if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) {
      icon = Icons.image;
      color = Colors.purple;
    } else if (['pdf'].contains(ext)) {
      icon = Icons.picture_as_pdf;
      color = Colors.red;
    } else if (['json', 'js', 'ts', 'dart', 'py', 'java', 'c', 'cpp', 'html', 'css', 'xml', 'yaml', 'yml'].contains(ext)) {
      icon = Icons.code;
      color = Colors.blue;
    } else if (['txt', 'md'].contains(ext)) {
      icon = Icons.description;
      color = Colors.orange;
    }

    return Icon(icon, color: color);
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  void _viewFile(BuildContext context, FileItem item) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: Text(item.attachment.name),
              leading: const CloseButton(),
              elevation: 0,
              backgroundColor: Colors.transparent,
              foregroundColor: Theme.of(context).colorScheme.onSurface,
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  item.attachment.content,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                   TextButton.icon(
                     onPressed: () {
                        Clipboard.setData(ClipboardData(text: item.attachment.content));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Content copied to clipboard')),
                        );
                     },
                     icon: const Icon(Icons.copy, size: 18),
                     label: const Text('Copy'),
                   ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, FileItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete File?'),
        content: Text('Are you sure you want to delete "${item.attachment.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(storageServiceProvider).deleteAttachment(
            item.chatId,
            item.message,
            item.attachment,
          );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File deleted')),
      );
    }
  }
}
