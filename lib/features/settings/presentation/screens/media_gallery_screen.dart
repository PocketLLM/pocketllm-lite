import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/providers.dart';
import '../../../../services/storage_service.dart';
import '../../../chat/presentation/providers/chat_provider.dart';

class MediaGalleryScreen extends ConsumerStatefulWidget {
  const MediaGalleryScreen({super.key});

  @override
  ConsumerState<MediaGalleryScreen> createState() => _MediaGalleryScreenState();
}

class _MediaGalleryScreenState extends ConsumerState<MediaGalleryScreen> {
  late Future<List<MediaItem>> _mediaFuture;

  @override
  void initState() {
    super.initState();
    _loadMedia();
  }

  void _loadMedia() {
    _mediaFuture = Future.microtask(() {
       return ref.read(storageServiceProvider).getAllMedia();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Media Gallery'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
               setState(() {
                 _loadMedia();
               });
            },
          ),
        ],
      ),
      body: FutureBuilder<List<MediaItem>>(
        future: _mediaFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
             return Center(child: Text('Error: ${snapshot.error}'));
          }

          final items = snapshot.data ?? [];

          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.image_not_supported_outlined, size: 64, color: theme.colorScheme.outline),
                  const SizedBox(height: 16),
                  Text('No images found', style: theme.textTheme.titleMedium),
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
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final tag = 'media_${item.hashCode}';

              return GestureDetector(
                onTap: () => _showFullScreenImage(context, item, tag),
                child: Hero(
                  tag: tag,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.memory(
                      base64Decode(item.imageUrl),
                      fit: BoxFit.cover,
                      cacheWidth: 300, // Optimization
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
            },
          );
        },
      ),
    );
  }

  void _showFullScreenImage(BuildContext context, MediaItem item, String tag) {
    showDialog(
      context: context,
      useSafeArea: false,
      builder: (context) => _FullScreenImageViewer(item: item, tag: tag),
    );
  }
}

class _FullScreenImageViewer extends ConsumerWidget {
  final MediaItem item;
  final String tag;

  const _FullScreenImageViewer({required this.item, required this.tag});

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
                tag: tag,
                child: Image.memory(
                  base64Decode(item.imageUrl),
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.broken_image, color: Colors.white, size: 64);
                  },
                ),
              ),
            ),
          ),

          // Top Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.black54,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              child: SafeArea(
                bottom: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                     IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Text(
                        DateFormat.yMMMd().add_jm().format(item.timestamp),
                        style: const TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 48), // Balance close button
                  ],
                ),
              ),
            ),
          ),

          // Bottom Bar (Jump to Chat)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.black54,
              padding: const EdgeInsets.all(16),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (item.messageContent != null && item.messageContent!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          item.messageContent!.length > 100
                              ? '${item.messageContent!.substring(0, 100)}...'
                              : item.messageContent!,
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    FilledButton.icon(
                      onPressed: () {
                        // Load session and navigate
                        Navigator.pop(context); // Close dialog

                        final storage = ref.read(storageServiceProvider);
                        final session = storage.getChatSession(item.chatId);

                        if (session != null) {
                           ref.read(chatProvider.notifier).loadSession(session);
                           context.go('/chat');
                        } else {
                           ScaffoldMessenger.of(context).showSnackBar(
                             const SnackBar(content: Text('Chat session not found')),
                           );
                        }
                      },
                      icon: const Icon(Icons.chat),
                      label: const Text('Go to Chat'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
