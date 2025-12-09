import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
// I'll stick to exporting to file, maybe showing a dialog where it is saved, or use share_plus if I added it.
// Checking deps... share_plus not added. I'll just save to Documents and show Snackbar path, or just skip "Export" if complex.
// The plan said "Rename/Export". I'll do "Rename" and "Delete". "Export" to txt file in Documents is doable.
import 'dart:io';

import '../../providers/chat_provider.dart';
import '../../providers/settings_provider.dart';
import '../../models/chat_session.dart';
import '../chat/chat_screen.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // We should watch the entire list from Hive
    // We created a provider `chatHistoryProvider` that returns List<ChatSession>.
    // But it's not a stream. We need to trigger refresh when things change.
    // The chat provider calls refresh() on history provider when sending messages.
    // So `ref.watch(chatHistoryProvider)` should work if we invalidate it correctly.
    final history = ref.watch(chatHistoryProvider);
    final settings = ref.watch(settingsProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Search not implemented yet')),
              );
            },
          ),
        ],
      ),
      body:
          history.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    const Text('No chat history'),
                    TextButton(
                      onPressed: () => context.go('/home'),
                      child: const Text('Start new chat'),
                    ),
                  ],
                ),
              )
              : ListView.builder(
                itemCount: history.length,
                itemBuilder: (context, index) {
                  final session = history[index];
                  return Dismissible(
                    key: Key(session.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    confirmDismiss: (direction) async {
                      return await showDialog(
                        context: context,
                        builder:
                            (context) => AlertDialog(
                              title: const Text('Delete Chat?'),
                              actions: [
                                TextButton(
                                  onPressed:
                                      () => Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text(
                                    'Delete',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                      );
                    },
                    onDismissed: (direction) {
                      ref.read(chatRepositoryProvider).deleteChat(session.id);
                      // Manually update list state? The repo delete doesn't auto trigger provider refresh unless we listen.
                      // We should trigger refresh.
                      ref.read(chatHistoryProvider.notifier).refresh();
                      if (settings?.isHapticEnabled == true)
                        HapticFeedback.mediumImpact();
                    },
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            Theme.of(context).colorScheme.primaryContainer,
                        child: Icon(
                          Icons.chat_bubble_outline,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      title: Text(
                        session.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${session.modelId} • ${DateFormat.MMMd().add_jm().format(session.lastUpdated)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () {
                        // Navigate to chat with ID
                        // We need to push the chat screen with this ID.
                        // Since we are in a ShellRoute, we can just go to /home but pass extra?
                        // Or define a sub-route.
                        // Currently /home maps to ChatScreen without ID.
                        // Let's rely on `currentChatId` logic in ChatScreen or passing data.
                        // A better way with GoRouter is `/chat/:id`.
                        // But our router setup is `/home`, `/history`, `/settings`.
                        // We can push a new route on top of the shell?
                        // Or assume /home can take parameters?
                        // Let's modify Router to accept ID for /home, or add a separate route `/chat/:id` OUTSIDE the shell?
                        // The prompt said "Chat Screen (Home Tab)". So it's inside the tab.
                        // If we click history item, we want to go to the Chat Tab and load that chat.

                        // Strategy: Update a provider that ChatScreen watches for "Active Chat ID", then switch tab.
                        // OR: Use `context.go('/home', extra: session.id)`.
                        // ChatScreen needs to handle 'extra'.

                        // Let's try updating `currentChatId` in the ChatScreen via a Shared Provider?
                        // We can just create a `selectedChatIdProvider`.
                        // But `ChatScreen` logic is local state `_currentChatId`.
                        // I'll update ChatScreen to check `GoRouterState.of(context).extra`.

                        context.go('/home', extra: session.id);
                      },
                      onLongPress: () {
                        if (settings?.isHapticEnabled == true)
                          HapticFeedback.selectionClick();
                        _showOptionsSheet(context, ref, session);
                      },
                    ),
                  );
                },
              ),
    );
  }

  void _showOptionsSheet(
    BuildContext context,
    WidgetRef ref,
    ChatSession session,
  ) {
    showModalBottomSheet(
      context: context,
      builder:
          (context) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Rename'),
                onTap: () {
                  Navigator.pop(context);
                  _showRenameDialog(context, ref, session);
                },
              ),
              ListTile(
                leading: const Icon(Icons.file_download),
                title: const Text('Export to Text'),
                onTap: () {
                  Navigator.pop(context);
                  _exportChat(context, session);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await ref.read(chatRepositoryProvider).deleteChat(session.id);
                  ref.read(chatHistoryProvider.notifier).refresh();
                },
              ),
            ],
          ),
    );
  }

  void _showRenameDialog(
    BuildContext context,
    WidgetRef ref,
    ChatSession session,
  ) {
    final controller = TextEditingController(text: session.title);
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Rename Chat'),
            content: TextField(controller: controller, autofocus: true),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  // We need a method in repo to update title.
                  // It's not strictly in "ChatRepository" interface I wrote, but I can add it or just hack it:
                  // "updateChatModel" exists. I need "updateChatTitle".
                  // I'll add `updateChatTitle` to ChatRepository now.
                  // Wait, I can't easily modify the file in this turn without overwriting.
                  // I'll manually get session, modify, save.
                  // The repo methods are just convenience.

                  Navigator.pop(context);
                  await ref
                      .read(chatRepositoryProvider)
                      .updateChatTitle(session.id, controller.text);
                  ref.read(chatHistoryProvider.notifier).refresh();
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  Future<void> _exportChat(BuildContext context, ChatSession session) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File(
        '${directory.path}/${session.title.replaceAll(RegExp(r'[^\w\s]+'), '')}_${session.id.substring(0, 4)}.txt',
      );

      final StringBuffer buffer = StringBuffer();
      buffer.writeln('Chat: ${session.title}');
      buffer.writeln('Date: ${session.lastUpdated}');
      buffer.writeln('Model: ${session.modelId}');
      buffer.writeln('-' * 20);

      for (var msg in session.messages) {
        buffer.writeln('${msg.isUser ? "User" : "AI"}: ${msg.text}');
        if (msg.imageBase64 != null) buffer.writeln('[Image Attached]');
        buffer.writeln('');
      }

      await file.writeAsString(buffer.toString());

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Exported to ${file.path}')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }
}
