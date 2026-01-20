import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../../core/providers.dart';
import '../../domain/models/chat_session.dart';
import '../providers/chat_provider.dart';

class ArchivedChatsScreen extends ConsumerStatefulWidget {
  const ArchivedChatsScreen({super.key});

  @override
  ConsumerState<ArchivedChatsScreen> createState() =>
      _ArchivedChatsScreenState();
}

class _ArchivedChatsScreenState extends ConsumerState<ArchivedChatsScreen> {
  @override
  Widget build(BuildContext context) {
    final storage = ref.watch(storageServiceProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Archived Chats'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ValueListenableBuilder<Box<ChatSession>>(
        valueListenable: storage.chatBoxListenable,
        builder: (context, box, _) {
          final sessions = storage.getChatSessions();
          final archivedSessions = sessions
              .where((s) => storage.isArchived(s.id))
              .toList();

          if (archivedSessions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.archive_outlined,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No archived chats',
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
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: archivedSessions.length,
            itemBuilder: (context, index) {
              final session = archivedSessions[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  child: Icon(
                    Icons.archive,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
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
                onTap: () {
                  // Peek at chat or restore?
                  // Let's show options sheet
                  _showArchivedSessionOptions(session);
                },
                trailing: IconButton(
                  icon: const Icon(Icons.unarchive),
                  tooltip: 'Unarchive',
                  onPressed: () async {
                    HapticFeedback.mediumImpact();
                    await storage.toggleArchive(session.id);
                    if (!context.mounted) return;
                    setState(() {}); // Refresh list to remove unarchived item
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Chat unarchived')),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _showArchivedSessionOptions(ChatSession session) {
    final storage = ref.read(storageServiceProvider);

    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.unarchive),
              title: const Text('Unarchive Chat'),
              onTap: () async {
                Navigator.pop(sheetContext);
                await storage.toggleArchive(session.id);
                if (!mounted) return;
                setState(() {}); // Refresh list to remove unarchived item
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Chat unarchived')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: const Text('Open Chat'),
              subtitle: const Text('Will unarchive automatically'),
              onTap: () async {
                Navigator.pop(sheetContext);
                // Unarchive and open
                await storage.toggleArchive(session.id);
                if (!mounted) return;
                ref.read(chatProvider.notifier).loadSession(session);
                // Pop Archive screen to go back to History -> Chat or just go to Chat?
                // ChatProvider loads session, but we need to navigate to ChatScreen.
                // Assuming ChatHistoryScreen was pushed from ChatScreen or Main wrapper.
                // If we are in ArchivedChatsScreen, we need to pop to main, then to Chat.
                // Simplest: Pop this screen, Pop History (if pushed), etc.
                // But if History is a tab, we just need to switch to Chat tab.
                // Wait, ChatHistoryScreen is usually a pushed screen from ChatScreen (drawer or button).
                // If we assume standard nav:
                // ChatScreen -> History -> Archive
                // We want: ChatScreen (with session loaded).
                // So we pop Archive, pop History.
                Navigator.of(context).pop(); // Pop Archive
                if (mounted) {
                  Navigator.of(
                    context,
                  ).pop(); // Pop History (back to ChatScreen)
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text(
                'Delete Permanently',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _confirmDelete(session.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(String id) async {
    // Direct delete for archived items? Or still require ad?
    // Consistency says require ad/confirmation.
    // Reuse logic? It's duplicated code.
    // For this task, I'll simple confirmation dialog without ad for now (Archived items might be less critical or just standard delete).
    // Or I should copy the ad logic to be "Professional".
    // Let's stick to simple confirmation for speed/cleanliness unless "Professional" demands ad.
    // The ad logic is specific to `ChatHistoryScreen` ad service. I don't want to duplicate 50 lines of ad logic here.
    // Simple delete is fine for "Archived".

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chat?'),
        content: const Text('This will permanently delete this chat.'),
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

    if (confirm == true && mounted) {
      final storage = ref.read(storageServiceProvider);
      await storage.deleteChatSession(id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Chat deleted')));
      }
    }
  }
}
