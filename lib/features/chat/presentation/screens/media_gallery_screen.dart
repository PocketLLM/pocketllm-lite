import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers.dart';
import '../../../../core/utils/image_decoder.dart';
import '../../domain/models/media_item.dart';
import '../providers/chat_provider.dart';

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
    final imagesAsync = ref.watch(mediaGalleryProvider);

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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
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
                    'No images found',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Images shared in chats will appear here',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
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
              return MediaThumbnail(
                item: images[index],
                onTap: () => _openViewer(context, images, index),
              );
            },
          );
        },
      ),
    );
  }

  void _openViewer(
    BuildContext context,
    List<MediaItem> images,
    int initialIndex,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            ImageViewerScreen(images: images, initialIndex: initialIndex),
      ),
    );
  }
}

class MediaThumbnail extends StatefulWidget {
  final MediaItem item;
  final VoidCallback onTap;

  const MediaThumbnail({super.key, required this.item, required this.onTap});

  @override
  State<MediaThumbnail> createState() => _MediaThumbnailState();
}

class _MediaThumbnailState extends State<MediaThumbnail> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  void _decode() async {
    // IsolateImageDecoder handles caching and background decoding
    final list = await IsolateImageDecoder.decodeImages([
      widget.item.base64Content,
    ]);
    if (mounted && list.isNotEmpty) {
      setState(() {
        _bytes = list.first;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_bytes == null) {
      return Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: widget.onTap,
      child: Hero(
        tag: widget.item.id,
        child: Image.memory(
          _bytes!,
          fit: BoxFit.cover,
          cacheWidth: 300, // Optimize thumbnail size
        ),
      ),
    );
  }
}

class ImageViewerScreen extends ConsumerWidget {
  final List<MediaItem> images;
  final int initialIndex;

  const ImageViewerScreen({
    super.key,
    required this.images,
    required this.initialIndex,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: PageView.builder(
        controller: PageController(initialPage: initialIndex),
        itemCount: images.length,
        itemBuilder: (context, index) {
          final item = images[index];
          return _FullImageView(item: item);
        },
      ),
    );
  }
}

class _FullImageView extends StatefulWidget {
  final MediaItem item;
  const _FullImageView({required this.item});

  @override
  State<_FullImageView> createState() => _FullImageViewState();
}

class _FullImageViewState extends State<_FullImageView> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  void _decode() async {
    final list = await IsolateImageDecoder.decodeImages([
      widget.item.base64Content,
    ]);
    if (mounted && list.isNotEmpty) {
      setState(() => _bytes = list.first);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_bytes == null) return const Center(child: CircularProgressIndicator());

    return Stack(
      children: [
        Center(
          child: Hero(
            tag: widget.item.id,
            child: InteractiveViewer(child: Image.memory(_bytes!)),
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            color: Colors.black54,
            padding:
                const EdgeInsets.all(16) +
                const EdgeInsets.only(bottom: 16), // Extra bottom padding
            child: Consumer(
              builder: (context, ref, _) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.item.chatTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat.yMMMd().add_jm().format(widget.item.timestamp),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () {
                        final storage = ref.read(storageServiceProvider);
                        final session = storage.getChatSession(
                          widget.item.chatId,
                        );
                        if (session != null) {
                          ref.read(chatProvider.notifier).loadSession(session);
                          // Navigate to chat.
                          // Since we are likely in a nested navigation stack (ChatHistory -> Gallery -> Viewer),
                          // context.go('/chat') clears the stack and goes to /chat, which is what we want.
                          context.go('/chat');
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Chat session no longer exists'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.chat_bubble_outline, size: 18),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white70),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      label: const Text('Go to Chat'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
