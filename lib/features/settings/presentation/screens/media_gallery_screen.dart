import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers.dart';
import '../../../chat/domain/models/media_item.dart';
import '../../../chat/presentation/providers/chat_provider.dart';

final mediaGalleryProvider = FutureProvider.autoDispose<List<MediaItem>>((
  ref,
) async {
  final storage = ref.watch(storageServiceProvider);
  return storage.getAllImages();
});

class MediaGalleryScreen extends ConsumerWidget {
  const MediaGalleryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaAsync = ref.watch(mediaGalleryProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Media Gallery')),
      body: mediaAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.image_not_supported_outlined,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No media found',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          // Group items by Month Year
          final groupedItems = <String, List<MediaItem>>{};
          for (final item in items) {
            final key = DateFormat('MMMM yyyy').format(item.timestamp);
            if (!groupedItems.containsKey(key)) {
              groupedItems[key] = [];
            }
            groupedItems[key]!.add(item);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: groupedItems.length,
            itemBuilder: (context, index) {
              final key = groupedItems.keys.elementAt(index);
              final groupItems = groupedItems[key]!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 12,
                    ),
                    child: Text(
                      key,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 4,
                          mainAxisSpacing: 4,
                        ),
                    itemCount: groupItems.length,
                    itemBuilder: (context, gridIndex) {
                      final item = groupItems[gridIndex];
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _showFullScreenImage(context, item);
                        },
                        child: Hero(
                          tag: 'media_${item.id}',
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              base64Decode(item.base64Image),
                              fit: BoxFit.cover,
                              cacheWidth: 300, // Optimize memory for thumbnails
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  void _showFullScreenImage(BuildContext context, MediaItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _FullScreenImageViewer(item: item),
      ),
    );
  }
}

class _FullScreenImageViewer extends ConsumerWidget {
  final MediaItem item;

  const _FullScreenImageViewer({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: () {
              // Load chat session and navigate
              final storage = ref.read(storageServiceProvider);
              final session = storage.getChatSession(item.chatId);
              if (session != null) {
                ref.read(chatProvider.notifier).loadSession(session);
                // Pop the full screen viewer first
                Navigator.pop(context);
                // Navigate to chat. We can't pop settings easily because we might be deep in navigation stack.
                // GoRouter's context.go('/chat') replaces the stack or goes to the route.
                context.go('/chat');
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Chat session not found')),
                );
              }
            },
            icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
            label: const Text(
              'Go to Chat',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: Center(
        child: Hero(
          tag: 'media_${item.id}',
          child: InteractiveViewer(
            child: Image.memory(
              base64Decode(item.base64Image),
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}
