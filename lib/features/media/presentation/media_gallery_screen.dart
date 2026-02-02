import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers.dart';
import 'package:pocketllm_lite/features/media/domain/models/media_item.dart';
import 'package:pocketllm_lite/features/chat/presentation/providers/chat_provider.dart';

class MediaGalleryScreen extends ConsumerStatefulWidget {
  const MediaGalleryScreen({super.key});

  @override
  ConsumerState<MediaGalleryScreen> createState() => _MediaGalleryScreenState();
}

class _MediaGalleryScreenState extends ConsumerState<MediaGalleryScreen> {
  List<MediaItem> _images = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    // Post-frame callback to avoid build conflicts
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final storage = ref.read(storageServiceProvider);
      // Run on a separate isolate or just async if heavy?
      // Since getAllImages iterates all messages, for MVP we run it here.
      // If it blocks UI, we might need isolate, but Hive objects are not easy to pass to isolates.
      final images = storage.getAllImages();
      if (mounted) {
        setState(() {
          _images = images;
          _isLoading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Media Gallery'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _images.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.image_not_supported_outlined,
                        size: 64,
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No images found in chats',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
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
                  itemCount: _images.length,
                  itemBuilder: (context, index) {
                    final item = _images[index];
                    return GestureDetector(
                      onTap: () {
                         _openViewer(context, index);
                      },
                      child: Hero(
                        tag: 'media_${item.id}',
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            base64Decode(item.base64),
                            fit: BoxFit.cover,
                            cacheWidth: 200, // Optimize memory for thumbnails
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
                ),
    );
  }

  void _openViewer(BuildContext context, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _MediaViewer(
          images: _images,
          initialIndex: initialIndex,
        ),
      ),
    );
  }
}

class _MediaViewer extends StatefulWidget {
  final List<MediaItem> images;
  final int initialIndex;

  const _MediaViewer({
    required this.images,
    required this.initialIndex,
  });

  @override
  State<_MediaViewer> createState() => _MediaViewerState();
}

class _MediaViewerState extends State<_MediaViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        title: Text(
            '${_currentIndex + 1} / ${widget.images.length}',
            style: const TextStyle(color: Colors.white),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
            PageView.builder(
            controller: _pageController,
            itemCount: widget.images.length,
            onPageChanged: (index) {
                setState(() => _currentIndex = index);
            },
            itemBuilder: (context, index) {
                final item = widget.images[index];
                return InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Center(
                      child: Hero(
                      tag: 'media_${item.id}',
                      child: Image.memory(
                          base64Decode(item.base64),
                          fit: BoxFit.contain,
                      ),
                      ),
                  ),
                );
            },
            ),
            Positioned(
                bottom: 32,
                left: 0,
                right: 0,
                child: Center(
                    child: Consumer(
                        builder: (context, ref, _) {
                            return FilledButton.icon(
                                onPressed: () {
                                    _jumpToChat(context, ref, widget.images[_currentIndex]);
                                },
                                icon: const Icon(Icons.chat),
                                label: const Text('View in Chat'),
                                style: FilledButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.black,
                                ),
                            );
                        }
                    ),
                ),
            ),
        ],
      ),
    );
  }

  Future<void> _jumpToChat(BuildContext context, WidgetRef ref, MediaItem item) async {
    final storage = ref.read(storageServiceProvider);
    final session = storage.getChatSession(item.chatId);

    if (session != null) {
        // Load the session into chat provider
        ref.read(chatProvider.notifier).loadSession(session);

        // Go to chat screen
        context.go('/chat');
    } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chat session not found')),
        );
    }
  }
}
