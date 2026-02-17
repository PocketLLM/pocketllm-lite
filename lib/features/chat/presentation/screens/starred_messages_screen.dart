import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers.dart';
import '../../../../core/widgets/m3_app_bar.dart';
import '../../domain/models/starred_message.dart';
import '../providers/chat_provider.dart';

class StarredMessagesScreen extends ConsumerStatefulWidget {
  const StarredMessagesScreen({super.key});

  @override
  ConsumerState<StarredMessagesScreen> createState() =>
      _StarredMessagesScreenState();
}

class _StarredMessagesScreenState extends ConsumerState<StarredMessagesScreen> {
  @override
  Widget build(BuildContext context) {
    final storage = ref.watch(storageServiceProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: M3AppBar(
        title: 'Starred Messages',
        onBack: () {
          if (GoRouter.of(context).canPop()) {
            context.pop();
          } else {
            context.go('/settings');
          }
        },
      ),
      body: ValueListenableBuilder(
        valueListenable: storage.settingsBoxListenable,
        builder: (context, box, _) {
          final starred = storage.getStarredMessages();
          // Sort by starredAt descending (newest stars first)
          starred.sort((a, b) => b.starredAt.compareTo(a.starredAt));

          if (starred.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.star_border,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No starred messages yet',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Long press a message in chat to star it',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.7,
                      ),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: starred.length,
            itemBuilder: (context, index) {
              final item = starred[index];
              final session = storage.getChatSession(item.chatId);
              final chatTitle = session?.title ?? 'Unknown Chat (Deleted)';
              final isDeleted = session == null;

              return Dismissible(
                key: Key(item.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: theme.colorScheme.error,
                  child: Icon(Icons.delete, color: theme.colorScheme.onError),
                ),
                onDismissed: (direction) {
                  storage.unstarMessage(item.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Message unstarred'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                child: Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () => _navigateToChat(item, session),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isDeleted
                                    ? Icons.delete_forever
                                    : Icons.chat_bubble_outline,
                                size: 14,
                                color: isDeleted
                                    ? theme.colorScheme.error
                                    : theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  chatTitle,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDeleted
                                        ? theme.colorScheme.error
                                        : theme.colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                DateFormat.yMMMd().format(
                                  item.message.timestamp,
                                ),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item.message.content,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium,
                          ),
                          if (item.message.images != null &&
                              item.message.images!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.image,
                                    size: 14,
                                    color: theme.colorScheme.secondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Image attached',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.colorScheme.secondary,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _navigateToChat(StarredMessage item, dynamic session) {
    if (session == null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Chat Deleted'),
          content: const Text(
            'The chat containing this message has been deleted. Do you want to remove this bookmark?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                final storage = ref.read(storageServiceProvider);
                await storage.unstarMessage(item.id);
              },
              child: const Text('Remove Bookmark'),
            ),
          ],
        ),
      );
      return;
    }

    HapticFeedback.lightImpact();
    ref.read(chatProvider.notifier).loadSession(session);
    // Navigate to Chat Screen
    // Assuming '/chat' is the route
    context.go('/chat');
  }
}
