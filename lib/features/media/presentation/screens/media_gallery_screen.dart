import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers.dart';
import '../../../chat/presentation/providers/chat_provider.dart';
import '../../domain/models/media_item.dart';

final mediaProvider = FutureProvider.autoDispose<List<MediaItem>>((ref) async {
  final storage = ref.watch(storageServiceProvider);
  return storage.getAllImages();
});

class MediaGalleryScreen extends ConsumerWidget {
  const MediaGalleryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaAsync = ref.watch(mediaProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Media Gallery'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(mediaProvider),
          ),
        ],
      ),
      body: mediaAsync.when(
        data: (mediaItems) {
          if (mediaItems.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.image_not_supported_outlined,
                    size: 64,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text('No images found', style: theme.textTheme.titleMedium),
                ],
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: mediaItems.length,
            itemBuilder: (context, index) {
              final item = mediaItems[index];
              return _buildThumbnail(context, ref, item);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildThumbnail(BuildContext context, WidgetRef ref, MediaItem item) {
    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    // Approx grid size is screenWidth / 3. Assuming min screen width 360, ~120px.
    // 200 is safe buffer.
    final cacheSize = (200 * devicePixelRatio).round();

    return GestureDetector(
      onTap: () => _showImageViewer(context, ref, item),
      child: Hero(
        tag: item.id,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            base64Decode(item.base64Image),
            fit: BoxFit.cover,
            cacheHeight: cacheSize,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey[300],
                child: const Icon(Icons.error),
              );
            },
          ),
        ),
      ),
    );
  }

  void _showImageViewer(BuildContext context, WidgetRef ref, MediaItem item) {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog.fullscreen(
        child: Stack(
          children: [
            InteractiveViewer(
              child: Center(
                child: Hero(
                  tag: item.id,
                  child: Image.memory(
                    base64Decode(item.base64Image),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 16,
              left: 16,
              child: SafeArea(
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(dialogContext),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black54,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: SafeArea(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              item.chatTitle,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              item.timestamp.toString().split('.')[0],
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.pop(dialogContext); // Close dialog
                          _jumpToChat(context, ref, item.chatId);
                        },
                        icon: const Icon(
                          Icons.chat_bubble_outline,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'Go to Chat',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _jumpToChat(BuildContext context, WidgetRef ref, String chatId) {
    final storage = ref.read(storageServiceProvider);
    final session = storage.getChatSession(chatId);
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
