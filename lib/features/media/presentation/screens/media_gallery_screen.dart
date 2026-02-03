import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../../../../core/providers.dart';
import '../../../../features/chat/presentation/providers/chat_provider.dart';
import '../../domain/models/media_item.dart';

class MediaGalleryScreen extends ConsumerWidget {
  const MediaGalleryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(storageServiceProvider);

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
      ),
      body: ValueListenableBuilder(
        valueListenable: storage.chatBoxListenable,
        builder: (context, box, _) {
          final mediaItems = storage.getAllImages();

          if (mediaItems.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.image_not_supported_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No images found in your chats',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 16,
                    ),
                  ),
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
              return GestureDetector(
                onTap: () => _showFullScreenImage(context, item),
                child: Hero(
                  tag: 'media_${item.hashCode}',
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image: DecorationImage(
                        image: MemoryImage(base64Decode(item.imageBase64)),
                        fit: BoxFit.cover,
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

  void _showFullScreenImage(BuildContext context, MediaItem item) {
    showDialog(
      context: context,
      builder: (context) => _FullScreenImageViewer(item: item),
    );
  }
}

class _FullScreenImageViewer extends ConsumerWidget {
  final MediaItem item;

  const _FullScreenImageViewer({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Hero(
                tag: 'media_${item.hashCode}',
                child: Image.memory(
                  base64Decode(item.imageBase64),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AppBar(
              backgroundColor: Colors.black.withValues(alpha: 0.5),
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.chatTitle,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  Text(
                    DateFormat.yMMMd().add_jm().format(item.timestamp),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 24,
            right: 24,
            child: FloatingActionButton.extended(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                _navigateToChat(context, ref, item.chatId);
              },
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('View in Chat'),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToChat(BuildContext context, WidgetRef ref, String chatId) {
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
