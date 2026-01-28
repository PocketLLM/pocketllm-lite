import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers.dart';
import '../../../chat/domain/models/media_item.dart';
import '../../../chat/presentation/providers/chat_provider.dart';

final mediaGalleryProvider =
    FutureProvider.autoDispose<List<MediaItem>>((ref) async {
  final storage = ref.watch(storageServiceProvider);
  return storage.getAllImages();
});

class MediaGalleryScreen extends ConsumerWidget {
  const MediaGalleryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imagesAsync = ref.watch(mediaGalleryProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Media Gallery'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(mediaGalleryProvider),
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
                    color: theme.disabledColor,
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
            itemCount: images.length,
            itemBuilder: (context, index) {
              final item = images[index];
              return _MediaThumbnail(item: item);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}

class _MediaThumbnail extends ConsumerWidget {
  final MediaItem item;

  const _MediaThumbnail({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => _FullImageViewer(item: item)),
        );
      },
      child: Hero(
        tag: 'media_${item.id}',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            base64Decode(item.base64Data),
            fit: BoxFit.cover,
            cacheWidth: 200, // Optimization
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey[300],
                child: const Icon(Icons.broken_image, color: Colors.grey),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FullImageViewer extends ConsumerWidget {
  final MediaItem item;

  const _FullImageViewer({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            tooltip: 'Go to Chat',
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
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Center(
        child: Hero(
          tag: 'media_${item.id}',
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Image.memory(
              base64Decode(item.base64Data),
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.broken_image, color: Colors.white, size: 64),
                    SizedBox(height: 16),
                    Text(
                      'Could not load image',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
