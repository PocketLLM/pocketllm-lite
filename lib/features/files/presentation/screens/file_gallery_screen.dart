import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers.dart';
import '../../../chat/domain/models/chat_session.dart';
import '../../../chat/presentation/providers/chat_provider.dart';
import '../../domain/models/file_item.dart';
import '../widgets/file_preview_dialog.dart';

class FileGalleryScreen extends ConsumerStatefulWidget {
  const FileGalleryScreen({super.key});

  @override
  ConsumerState<FileGalleryScreen> createState() => _FileGalleryScreenState();
}

class _FileGalleryScreenState extends ConsumerState<FileGalleryScreen> {
  String _searchQuery = '';
  String? _selectedExtension;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<FileItem> _filterFiles(List<FileItem> files) {
    return files.where((item) {
      // Filter by Search
      if (_searchQuery.isNotEmpty) {
        if (!item.attachment.name.toLowerCase().contains(
              _searchQuery.toLowerCase(),
            ) &&
            !item.attachment.content.toLowerCase().contains(
              _searchQuery.toLowerCase(),
            )) {
          return false;
        }
      }

      // Filter by Extension
      if (_selectedExtension != null) {
        final ext = item.attachment.name.split('.').last.toLowerCase();
        if (ext != _selectedExtension) return false;
      }

      return true;
    }).toList();
  }

  Set<String> _getAvailableExtensions(List<FileItem> files) {
    final extensions = <String>{};
    for (final file in files) {
      final parts = file.attachment.name.split('.');
      if (parts.length > 1) {
        extensions.add(parts.last.toLowerCase());
      } else {
        extensions.add('txt'); // Default if no extension
      }
    }
    return extensions;
  }

  void _handleFileTap(FileItem item) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => FilePreviewDialog(fileItem: item),
    );

    if (result == true && mounted) {
      final storage = ref.read(storageServiceProvider);
      final session = storage.getChatSession(item.chatId);
      if (session != null) {
        ref.read(chatProvider.notifier).loadSession(session);
        context.go('/chat');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat session not found')),
        );
      }
    }
  }

  String _formatBytes(int bytes) {
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
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
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
        ),
      ),
      body: ValueListenableBuilder<Box<ChatSession>>(
        valueListenable: storage.chatBoxListenable,
        builder: (context, box, _) {
          final allFiles = storage.getAllAttachments();
          final extensions = _getAvailableExtensions(allFiles);
          final filteredFiles = _filterFiles(allFiles);

          if (allFiles.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.folder_open,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.5,
                    ),
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

          return Column(
            children: [
              // Filter Chips
              if (extensions.isNotEmpty)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('All'),
                        selected: _selectedExtension == null,
                        onSelected: (selected) {
                          setState(() => _selectedExtension = null);
                        },
                      ),
                      ...extensions.map(
                        (ext) => Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: FilterChip(
                            label: Text(ext.toUpperCase()),
                            selected: _selectedExtension == ext,
                            onSelected: (selected) {
                              setState(
                                () => _selectedExtension = selected ? ext : null,
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // File List
              Expanded(
                child: filteredFiles.isEmpty
                    ? Center(
                        child: Text(
                          'No matching files found',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredFiles.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = filteredFiles[index];
                          final ext = item.attachment.name.split('.').last
                              .toLowerCase();

                          IconData icon;
                          Color color;

                          switch(ext) {
                            case 'json':
                              icon = Icons.data_object;
                              color = Colors.orange;
                              break;
                            case 'csv':
                              icon = Icons.table_chart;
                              color = Colors.green;
                              break;
                            case 'md':
                              icon = Icons.markdown;
                              color = Colors.blue;
                              break;
                            case 'txt':
                              icon = Icons.description;
                              color = Colors.grey;
                              break;
                            case 'log':
                              icon = Icons.terminal;
                              color = Colors.brown;
                              break;
                            default:
                              icon = Icons.insert_drive_file;
                              color = theme.colorScheme.primary;
                          }

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: color.withValues(alpha: 0.1),
                              child: Icon(icon, color: color),
                            ),
                            title: Text(
                              item.attachment.name,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Row(
                              children: [
                                Text(
                                  _formatBytes(item.attachment.sizeBytes),
                                  style: TextStyle(fontSize: 12),
                                ),
                                const SizedBox(width: 8),
                                const Text('•', style: TextStyle(fontSize: 12)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    DateFormat.yMMMd().format(item.timestamp),
                                    style: TextStyle(fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.arrow_forward_ios, size: 16),
                              onPressed: () => _handleFileTap(item),
                            ),
                            onTap: () => _handleFileTap(item),
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
}
