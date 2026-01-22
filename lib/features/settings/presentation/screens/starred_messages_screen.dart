import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers.dart';
import '../../../../services/storage_service.dart';
import '../../../chat/presentation/providers/chat_provider.dart';
import '../../../chat/domain/models/starred_message.dart';
import '../../../chat/presentation/screens/chat_screen.dart'; // To navigate

class StarredMessagesScreen extends ConsumerStatefulWidget {
  const StarredMessagesScreen({super.key});

  @override
  ConsumerState<StarredMessagesScreen> createState() =>
      _StarredMessagesScreenState();
}

class _StarredMessagesScreenState extends ConsumerState<StarredMessagesScreen> {
  String _searchQuery = '';
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

    // Get starred messages directly
    // Ideally this should be a ValueListenable if we want real-time updates when starring elsewhere
    // but since we are IN the screen, we only care if we unstar here.
    // If we want to be safe, we can wrap with ValueListenableBuilder on settings box,
    // but specific keys are hard to listen to efficiently without custom notifier.
    // For now, simple setState on unstar is enough.
    List<StarredMessage> starred = storage.getStarredMessages();

    // Sort by savedAt descending
    starred.sort((a, b) => b.savedAt.compareTo(a.savedAt));

    // Filter
    if (_searchQuery.isNotEmpty) {
      starred =
          starred
              .where(
                (s) => s.message.content.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ),
              )
              .toList();
    }

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
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search saved messages...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon:
                    _searchQuery.isNotEmpty
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
            child:
                starred.isEmpty
                    ? Center(
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
                            _searchQuery.isEmpty
                                ? 'No starred messages yet'
                                : 'No matching messages found',
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 16,
                            ),
                          ),
                          if (_searchQuery.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(
                                'Long press any message in a chat\nto save it here.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.7),
                                  fontSize: 14,
                                ),
                              ),
                            ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      itemCount: starred.length,
                      itemBuilder: (context, index) {
                        final item = starred[index];
                        final message = item.message;

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          elevation: 0,
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: theme.colorScheme.outlineVariant,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      message.role == 'user'
                                          ? Icons.person
                                          : Icons.auto_awesome,
                                      size: 16,
                                      color: theme.colorScheme.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      DateFormat.yMMMd().add_jm().format(
                                        message.timestamp,
                                      ),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: theme
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                    ),
                                    const Spacer(),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.star,
                                        color: Colors.orange,
                                        size: 20,
                                      ),
                                      onPressed: () async {
                                        await storage.toggleMessageStar(
                                          item.chatId,
                                          message,
                                        );
                                        setState(() {});
                                        if (mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text('Message removed'),
                                              duration: Duration(seconds: 1),
                                            ),
                                          );
                                        }
                                      },
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  message.content,
                                  maxLines: 5,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 15),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton.icon(
                                      onPressed: () {
                                        Clipboard.setData(
                                          ClipboardData(text: message.content),
                                        );
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text('Copied to clipboard'),
                                            duration: Duration(seconds: 1),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.copy, size: 16),
                                      label: const Text('Copy'),
                                    ),
                                    const SizedBox(width: 8),
                                    FilledButton.icon(
                                      onPressed: () async {
                                        // Navigate to chat
                                        final session = storage.getChatSession(
                                          item.chatId,
                                        );
                                        if (session != null) {
                                          ref
                                              .read(chatProvider.notifier)
                                              .loadSession(session);
                                          // Navigate
                                          context.go('/chat');
                                        } else {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Original chat not found',
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                      icon: const Icon(
                                        Icons.arrow_forward,
                                        size: 16,
                                      ),
                                      label: const Text('Go to Chat'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
