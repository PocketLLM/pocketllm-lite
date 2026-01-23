import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/providers.dart';
import '../../../../services/storage_service.dart';
import '../../domain/models/chat_message.dart';
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
      appBar: AppBar(
        title: const Text('Starred Messages'),
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
      ),
      body: ValueListenableBuilder(
        valueListenable: storage.settingsBoxListenable,
        builder: (context, box, _) {
          final starredMessages = storage.getStarredMessages();

          if (starredMessages.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.star_outline_rounded,
                    size: 80,
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No starred messages yet',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Long press a message in chat to star it',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: starredMessages.length,
            itemBuilder: (context, index) {
              final item = starredMessages[index];
              return _buildStarredItem(context, storage, item, theme);
            },
          );
        },
      ),
    );
  }

  Widget _buildStarredItem(
    BuildContext context,
    StorageService storage,
    Map<String, dynamic> item,
    ThemeData theme,
  ) {
    final messageJson = Map<String, dynamic>.from(item['message']);
    // Reconstruct ChatMessage (we need to duplicate logic from StorageService or make it public,
    // but here we can just do it manually or assume the structure matches)
    final message = ChatMessage(
      role: messageJson['role'],
      content: messageJson['content'],
      timestamp: DateTime.parse(messageJson['timestamp']),
      images:
          messageJson['images'] != null
              ? List<String>.from(messageJson['images'])
              : null,
    );

    final chatId = item['chatId'] as String;
    final chatTitle = item['chatTitle'] as String;
    final starredAt = DateTime.parse(item['starredAt']);
    final isUser = message.role == 'user';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: theme.colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: InkWell(
        onTap: () => _navigateToChat(chatId),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Chat Title & Date
              Row(
                children: [
                  Icon(
                    isUser ? Icons.person : Icons.auto_awesome,
                    size: 16,
                    color:
                        isUser
                            ? theme.colorScheme.primary
                            : theme.colorScheme.secondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      chatTitle,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    DateFormat.MMMd().format(message.timestamp),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Content Preview
              Text(
                message.content,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
              if (message.images != null && message.images!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.image,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Contains ${message.images!.length} image(s)',
                        style: theme.textTheme.caption?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              // Footer Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    tooltip: 'Copy',
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: message.content));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Copied to clipboard'),
                          behavior: SnackBarBehavior.floating,
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.share, size: 18),
                    tooltip: 'Share',
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      SharePlus.instance.share(
                        ShareParams(text: message.content),
                      );
                    },
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.star,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    tooltip: 'Unstar',
                    visualDensity: VisualDensity.compact,
                    onPressed: () async {
                      await storage.removeStarredMessage(message);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Message unstarred'),
                            action: SnackBarAction(
                              label: 'Undo',
                              onPressed: () async {
                                await storage.saveStarredMessage(
                                  message: message,
                                  chatId: chatId,
                                  chatTitle: chatTitle,
                                );
                              },
                            ),
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _navigateToChat(String chatId) async {
    final storage = ref.read(storageServiceProvider);
    final session = storage.getChatSession(chatId);

    if (session != null) {
      ref.read(chatProvider.notifier).loadSession(session);
      context.go('/chat');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Original chat no longer exists'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
