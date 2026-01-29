import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers.dart';
import '../../domain/models/media_item.dart';
import '../providers/chat_provider.dart';

final mediaGalleryProvider = FutureProvider.autoDispose<List<MediaItem>>((ref) async {
  final storage = ref.watch(storageServiceProvider);
  // Use Future to allow UI to render frame before heavy lifting
  return Future.value(storage.getAllImages());
});

class MediaGalleryScreen extends ConsumerWidget {
  const MediaGalleryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imagesAsync = ref.watch(mediaGalleryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Media Gallery'),
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
                    color: Theme.of(context).colorScheme.outline
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No images found',
                    style: Theme.of(context).textTheme.titleMedium
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
              final tag = '${item.chatId}_${item.timestamp.millisecondsSinceEpoch}_$index';

              return GestureDetector(
                onTap: () => _showImageDialog(context, ref, item, tag),
                child: Hero(
                  tag: tag,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black12,
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

  void _showImageDialog(BuildContext context, WidgetRef ref, MediaItem item, String tag) {
    showDialog(
      context: context,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: Hero(
                  tag: tag,
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
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  TextButton.icon(
                    icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
                    label: const Text('Go to Chat', style: TextStyle(color: Colors.white)),
                    onPressed: () {
                       Navigator.pop(context); // Close dialog

                       // Load session and navigate
                       final storage = ref.read(storageServiceProvider);
                       final session = storage.getChatSession(item.chatId);
                       if (session != null) {
                         ref.read(chatProvider.notifier).loadSession(session);
                         context.go('/chat');
                       }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
