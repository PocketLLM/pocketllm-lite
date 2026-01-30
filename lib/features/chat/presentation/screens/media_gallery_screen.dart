import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers.dart';
import '../../domain/models/media_item.dart';
import '../providers/chat_provider.dart';

final galleryImagesProvider = FutureProvider.autoDispose<List<MediaItem>>((ref) async {
  final storage = ref.watch(storageServiceProvider);
  return storage.getAllImages();
});

class MediaGalleryScreen extends ConsumerWidget {
  const MediaGalleryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imagesAsync = ref.watch(galleryImagesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Media Gallery'),
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(galleryImagesProvider);
            },
          ),
        ],
      ),
      body: imagesAsync.when(
        data: (images) {
          if (images.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.image_not_supported_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No images found in your chats.',
                    style: TextStyle(color: Theme.of(context).colorScheme.outline),
                  ),
                ],
              ),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(4),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: images.length,
            itemBuilder: (context, index) {
              final item = images[index];
              return GestureDetector(
                onTap: () => _showFullImage(context, item),
                child: Hero(
                  tag: 'image_${item.chatId}_${item.messageTimestamp.millisecondsSinceEpoch}_${item.index}',
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.memory(
                      base64Decode(item.base64Image),
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      errorBuilder: (context, error, stackTrace) => const Center(
                        child: Icon(Icons.broken_image, size: 24, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, stack) => Center(child: Text('Error: $e')),
      ),
    );
  }

  void _showFullImage(BuildContext context, MediaItem item) {
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
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          TextButton.icon(
            onPressed: () {
              final storage = ref.read(storageServiceProvider);
              final session = storage.getChatSession(item.chatId);
              if (session != null) {
                ref.read(chatProvider.notifier).loadSession(session);
                context.go('/chat');
              } else {
                 ScaffoldMessenger.of(context).showSnackBar(
                   const SnackBar(content: Text('Chat not found')),
                 );
              }
            },
            icon: const Icon(Icons.chat, color: Colors.white),
            label: const Text('Go to Chat', style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: Hero(
          tag: 'image_${item.chatId}_${item.messageTimestamp.millisecondsSinceEpoch}_${item.index}',
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Image.memory(
              base64Decode(item.base64Image),
              fit: BoxFit.contain,
              gaplessPlayback: true,
            ),
          ),
        ),
      ),
    );
  }
}
