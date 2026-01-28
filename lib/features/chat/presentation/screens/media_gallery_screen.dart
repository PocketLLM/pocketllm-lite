import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers.dart';
import '../../domain/models/media_item.dart';
import '../providers/chat_provider.dart';

class MediaGalleryScreen extends ConsumerStatefulWidget {
  const MediaGalleryScreen({super.key});

  @override
  ConsumerState<MediaGalleryScreen> createState() => _MediaGalleryScreenState();
}

class _MediaGalleryScreenState extends ConsumerState<MediaGalleryScreen> {
  // Use a Future to load images so we can refresh it
  late Future<List<MediaItem>> _imagesFuture;

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  void _loadImages() {
    _imagesFuture = Future.microtask(() {
      final storage = ref.read(storageServiceProvider);
      return storage.getAllImages();
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
              HapticFeedback.selectionClick();
              setState(() {
                _loadImages();
              });
            },
          ),
        ],
      ),
      body: FutureBuilder<List<MediaItem>>(
        future: _imagesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
                  const SizedBox(height: 16),
                  Text('Error loading images: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => setState(() => _loadImages()),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final images = snapshot.data ?? [];

          if (images.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.image_not_supported_outlined, size: 64, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  Text(
                    'No images found in chat history',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
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
            itemCount: images.length,
            itemBuilder: (context, index) {
              final item = images[index];
              return GestureDetector(
                onTap: () => _openFullScreen(context, images, index),
                child: Hero(
                  tag: 'media_gallery_${item.timestamp.millisecondsSinceEpoch}_$index',
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

  void _openFullScreen(BuildContext context, List<MediaItem> images, int initialIndex) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _FullScreenViewer(
          images: images,
          initialIndex: initialIndex,
        ),
      ),
    );
  }
}

class _FullScreenViewer extends ConsumerStatefulWidget {
  final List<MediaItem> images;
  final int initialIndex;

  const _FullScreenViewer({
    required this.images,
    required this.initialIndex,
  });

  @override
  ConsumerState<_FullScreenViewer> createState() => _FullScreenViewerState();
}

class _FullScreenViewerState extends ConsumerState<_FullScreenViewer> {
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

  void _jumpToChat(MediaItem item) {
    HapticFeedback.mediumImpact();
    final storage = ref.read(storageServiceProvider);
    final session = storage.getChatSession(item.chatId);

    if (session != null) {
      // Load session and navigate
      ref.read(chatProvider.notifier).loadSession(session);

      // Navigate to chat. We use go() which replaces the stack.
      // This is generally what we want if we're jumping contexts.
      context.go('/chat');
    } else {
       ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat session not found')),
       );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentItem = widget.images[_currentIndex];
    final dateStr = DateFormat.yMMMd().add_jm().format(currentItem.timestamp);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.5),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Text(
              '${_currentIndex + 1} of ${widget.images.length}',
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              dateStr,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () => _jumpToChat(currentItem),
            icon: const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 20),
            label: const Text('Go to Chat', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: PageView.builder(
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
            child: Hero(
              tag: 'media_gallery_${item.timestamp.millisecondsSinceEpoch}_$index',
              child: Image.memory(
                base64Decode(item.imageBase64),
                fit: BoxFit.contain,
              ),
            ),
          );
        },
      ),
    );
  }
}
