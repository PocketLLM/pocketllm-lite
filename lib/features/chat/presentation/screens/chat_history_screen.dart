import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../../core/providers.dart';
import '../../domain/models/chat_session.dart';
import '../providers/chat_provider.dart';

class ChatHistoryScreen extends ConsumerStatefulWidget {
  const ChatHistoryScreen({super.key});

  @override
  ConsumerState<ChatHistoryScreen> createState() => _ChatHistoryScreenState();
}

class _ChatHistoryScreenState extends ConsumerState<ChatHistoryScreen> {
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  @override
  Widget build(BuildContext context) {
    final storage = ref.watch(storageServiceProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isSelectionMode ? '${_selectedIds.length} Selected' : 'Chat History',
        ),
        actions: [
          if (_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: _selectedIds.isEmpty ? null : _deleteSelected,
            )
          else
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
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _isSelectionMode = false;
                    _selectedIds.clear();
                  });
                },
              )
            : const BackButton(), // Defaults to back arrow
      ),
      body: Column(
        children: [
          if (_isSelectionMode)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: theme.colorScheme.surfaceContainer,
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

          Expanded(
            child: ValueListenableBuilder<Box<ChatSession>>(
              valueListenable: storage.chatBoxListenable,
              builder: (context, box, _) {
                final sessions = box.values.toList()
                  ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

                if (sessions.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history_toggle_off,
                          size: 60,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No chat history',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: sessions.length,
                  itemBuilder: (context, index) {
                    final session = sessions[index];
                    final isSelected = _selectedIds.contains(session.id);

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
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
                          : CircleAvatar(
                              backgroundColor:
                                  theme.colorScheme.primaryContainer,
                              child: Icon(
                                Icons.chat_bubble_outline,
                                size: 20,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                      title: Text(
                        session.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        _formatDate(session.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      trailing: !_isSelectionMode
                          ? IconButton(
                              icon: const Icon(Icons.chevron_right),
                              onPressed: () => _loadSession(session),
                            )
                          : null,
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
        ],
      ),
      floatingActionButton: _isSelectionMode
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                HapticFeedback.mediumImpact();
                ref.read(chatProvider.notifier).newChat();
                Navigator.pop(context); // Go back to chat screen with new chat
              },
              label: const Text('New Chat'),
              icon: const Icon(Icons.add),
            ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _loadSession(ChatSession session) {
    ref.read(chatProvider.notifier).loadSession(session);
    Navigator.pop(context);
  }

  void _showSessionOptions(ChatSession session) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Rename Chat'),
              onTap: () {
                Navigator.pop(context);
                _showRenameDialog(session);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text(
                'Delete Chat',
                style: TextStyle(color: Colors.red),
              ),
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
          decoration: const InputDecoration(
            labelText: 'Chat Title',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
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
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
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
