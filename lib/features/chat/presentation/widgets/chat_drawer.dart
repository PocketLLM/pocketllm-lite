import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../../core/providers.dart';
import '../../domain/models/chat_session.dart';
import '../providers/chat_provider.dart';

class ChatDrawer extends ConsumerStatefulWidget {
  const ChatDrawer({super.key});

  @override
  ConsumerState<ChatDrawer> createState() => _ChatDrawerState();
}

class _ChatDrawerState extends ConsumerState<ChatDrawer> {
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  @override
  Widget build(BuildContext context) {
    final storage = ref.watch(storageServiceProvider);

    return Drawer(
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
              bottom: 16,
              left: 16,
              right: 16,
            ),
            color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            child: Row(
              children: [
                if (_isSelectionMode)
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _isSelectionMode = false;
                        _selectedIds.clear();
                      });
                    },
                  )
                else
                  const Icon(Icons.history, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _isSelectionMode
                        ? '${_selectedIds.length} Selected'
                        : 'Chat History',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (_isSelectionMode) ...[
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: _selectedIds.isEmpty ? null : _deleteSelected,
                  ),
                ] else ...[
                  // "Select All" / Edit Mode Button
                  IconButton(
                    icon: const Icon(Icons.checklist),
                    tooltip: 'Manage Chats',
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _isSelectionMode = true;
                      });
                    },
                  ),
                ],
              ],
            ),
          ),

          if (_isSelectionMode)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      final box = storage.chatBoxListenable.value;
                      setState(() {
                        if (_selectedIds.length == box.length) {
                          _selectedIds.clear();
                        } else {
                          _selectedIds.addAll(box.keys.cast<String>());
                        }
                      });
                    },
                    icon: Icon(
                      _selectedIds.isNotEmpty
                          ? Icons.deselect
                          : Icons.select_all,
                    ),
                    label: Text(
                      _selectedIds.isNotEmpty ? 'Deselect All' : 'Select All',
                    ),
                  ),
                ],
              ),
            ),

          // List
          Expanded(
            child: ValueListenableBuilder<Box<ChatSession>>(
              valueListenable: storage.chatBoxListenable,
              builder: (context, box, _) {
                final sessions = box.values.toList()
                  ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

                if (sessions.isEmpty) {
                  return const Center(
                    child: Text(
                      'No history yet',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: sessions.length,
                  itemBuilder: (context, index) {
                    final session = sessions[index];
                    final isSelected = _selectedIds.contains(session.id);

                    return ListTile(
                      leading: _isSelectionMode
                          ? Checkbox(
                              value: isSelected,
                              onChanged: (val) {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  if (val == true) {
                                    _selectedIds.add(session.id);
                                  } else {
                                    _selectedIds.remove(session.id);
                                  }
                                });
                              },
                            )
                          : const Icon(Icons.chat_bubble_outline, size: 20),
                      title: Text(
                        session.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        _formatDate(session.createdAt),
                        style: const TextStyle(fontSize: 12),
                      ),
                      onTap: () {
                        if (_isSelectionMode) {
                          HapticFeedback.selectionClick();
                          setState(() {
                            if (isSelected) {
                              _selectedIds.remove(session.id);
                            } else {
                              _selectedIds.add(session.id);
                            }
                          });
                        } else {
                          HapticFeedback.lightImpact();
                          _loadSession(session);
                        }
                      },
                      onLongPress: _isSelectionMode
                          ? null
                          : () {
                              HapticFeedback.mediumImpact();
                              _showSessionOptions(session);
                            },
                    );
                  },
                );
              },
            ),
          ),

          const Divider(),
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('New Chat'),
            onTap: () {
              HapticFeedback.lightImpact();
              ref.read(chatProvider.notifier).newChat();
              Navigator.pop(context); // Close drawer
            },
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    // Simple formatter, can use intl but keeping it dependency-free for this snippet if possible or just simple logic
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _loadSession(ChatSession session) {
    ref.read(chatProvider.notifier).loadSession(session);
    Navigator.pop(context);
  }

  void _showSessionOptions(ChatSession session) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Rename'),
              onTap: () {
                Navigator.pop(context);
                _showRenameDialog(session);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deleteSession(session.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(ChatSession session) {
    final controller = TextEditingController(text: session.title);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Chat'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Chat Title'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                final storage = ref.read(storageServiceProvider);
                final updated = session.copyWith(title: controller.text.trim());
                storage.saveChatSession(updated);
                HapticFeedback.mediumImpact();
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSession(String id) async {
    final storage = ref.read(storageServiceProvider);
    await storage.deleteChatSession(id);
    HapticFeedback.mediumImpact();
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Selected?'),
        content: Text(
          'Delete ${_selectedIds.length} chats? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final storage = ref.read(storageServiceProvider);
      for (final id in _selectedIds) {
        await storage.deleteChatSession(id);
      }
      setState(() {
        _selectedIds.clear();
        _isSelectionMode = false;
      });
      HapticFeedback.heavyImpact();
    }
  }
}
