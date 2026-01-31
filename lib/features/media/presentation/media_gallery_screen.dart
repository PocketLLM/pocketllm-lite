import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers.dart';
import '../../../../core/utils/image_decoder.dart';
import '../domain/media_item.dart';

final mediaGalleryProvider = FutureProvider.autoDispose<List<MediaItem>>((ref) async {
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
               HapticFeedback.lightImpact();
               ref.invalidate(mediaGalleryProvider);
            },
          ),
        ],
      ),
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
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No images found in chats',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
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
            itemCount: items.length,
            itemBuilder: (context, index) {
              return _MediaGridItem(
                item: items[index],
                onTap: () => _showFullScreenImage(context, items[index]),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Text('Error: $err', style: TextStyle(color: theme.colorScheme.error)),
        ),
      ),
    );
  }

  void _showFullScreenImage(BuildContext context, MediaItem item) {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => _FullScreenImageViewer(item: item),
    );
  }
}

class _MediaGridItem extends StatefulWidget {
  final MediaItem item;
  final VoidCallback onTap;

  const _MediaGridItem({required this.item, required this.onTap});

  @override
  State<_MediaGridItem> createState() => _MediaGridItemState();
}

class _MediaGridItemState extends State<_MediaGridItem> {
  Future<Uint8List>? _decodeFuture;

  @override
  void initState() {
    super.initState();
    // Use IsolateImageDecoder to decode in background
    _decodeFuture = _decodeImage();
  }

  Future<Uint8List> _decodeImage() async {
    final results = await IsolateImageDecoder.decodeImages([widget.item.base64Content]);
    return results.first;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(8),
      child: FutureBuilder<Uint8List>(
        future: _decodeFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Hero(
                tag: 'media_${widget.item.hashCode}',
                child: Image.memory(
                  snapshot.data!,
                  fit: BoxFit.cover,
                  cacheHeight: (200 * MediaQuery.of(context).devicePixelRatio).round(),
                ),
              ),
            );
          } else if (snapshot.hasError) {
             return Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.broken_image, size: 24),
            );
          } else {
             return Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            );
          }
        },
      ),
    );
  }
}

class _FullScreenImageViewer extends StatefulWidget {
  final MediaItem item;

  const _FullScreenImageViewer({required this.item});

  @override
  State<_FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<_FullScreenImageViewer> {
  Future<Uint8List>? _decodeFuture;

  @override
  void initState() {
    super.initState();
    _decodeFuture = _decodeImage();
  }

  Future<Uint8List> _decodeImage() async {
     final results = await IsolateImageDecoder.decodeImages([widget.item.base64Content]);
    return results.first;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        alignment: Alignment.center,
        children: [
          InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: FutureBuilder<Uint8List>(
              future: _decodeFuture,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return Hero(
                     tag: 'media_${widget.item.hashCode}',
                     child: Image.memory(snapshot.data!),
                  );
                } else {
                  return const CircularProgressIndicator(color: Colors.white);
                }
              },
            ),
          ),
          Positioned(
            top: 40,
            right: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Positioned(
             bottom: 40,
             child: Container(
               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
               decoration: BoxDecoration(
                 color: Colors.black54,
                 borderRadius: BorderRadius.circular(20),
               ),
               child: Text(
                 _formatDate(widget.item.timestamp),
                 style: const TextStyle(color: Colors.white),
               ),
             ),
          )
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
  }
}
