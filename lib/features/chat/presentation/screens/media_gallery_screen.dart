import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers.dart';
import '../../domain/models/media_item.dart';
import '../providers/chat_provider.dart';

class MediaGalleryScreen extends ConsumerStatefulWidget {
  const MediaGalleryScreen({super.key});

  @override
  ConsumerState<MediaGalleryScreen> createState() => _MediaGalleryScreenState();
}

class _MediaGalleryScreenState extends ConsumerState<MediaGalleryScreen> {
  List<MediaItem>? _items;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGallery();
  }

  Future<void> _loadGallery() async {
    // Defer to next frame to allow UI to render loading state
    await Future.delayed(Duration.zero);
    if (!mounted) return;

    final storage = ref.read(storageServiceProvider);
    final items = storage.getMediaGallery();

    setState(() {
      _items = items;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Media Gallery'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _items == null || _items!.isEmpty
              ? Center(
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
                        'No images found in history',
                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant)
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _items!.length,
                  itemBuilder: (context, index) {
                    final item = _items![index];
                    final imageBytes = base64Decode(item.base64Content);

                    return GestureDetector(
                      onTap: () => _openFullScreen(context, item, imageBytes),
                      child: Hero(
                        tag: 'gallery_${item.chatId}_${item.messageIndex}_${item.imageIndex}',
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: theme.colorScheme.surfaceContainerHighest,
                            image: DecorationImage(
                              image: MemoryImage(imageBytes),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  void _openFullScreen(BuildContext context, MediaItem item, Uint8List bytes) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _FullScreenViewer(item: item, bytes: bytes),
      ),
    );
  }
}

class _FullScreenViewer extends ConsumerWidget {
  final MediaItem item;
  final Uint8List bytes;

  const _FullScreenViewer({required this.item, required this.bytes});

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
               final storage = ref.read(storageServiceProvider);
               final session = storage.getChatSession(item.chatId);
               if (session != null) {
                 ref.read(chatProvider.notifier).loadSession(session);
                 // Navigate back to chat screen
                 context.go('/chat');
               }
            },
            icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
            label: const Text('Go to Chat', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Hero(
            tag: 'gallery_${item.chatId}_${item.messageIndex}_${item.imageIndex}',
            child: Image.memory(bytes),
          ),
        ),
      ),
    );
  }
}
