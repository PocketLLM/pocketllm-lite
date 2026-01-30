import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/providers.dart';
import '../../../chat/domain/models/media_item.dart';
import '../../../chat/presentation/providers/chat_provider.dart';

final mediaGalleryProvider = FutureProvider.autoDispose<List<MediaItem>>((ref) async {
  final storage = ref.watch(storageServiceProvider);
  return Future.value(storage.getAllImages());
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(mediaGalleryProvider),
          ),
        ],
      ),
      body: mediaAsync.when(
        data: (mediaItems) {
          if (mediaItems.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.image_not_supported_outlined,
                    size: 64,
                    color: theme.colorScheme.outline,
                  ),
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
            itemCount: mediaItems.length,
            itemBuilder: (context, index) {
              final item = mediaItems[index];
              return GestureDetector(
                onTap:
                    () =>
                        _showFullScreenViewer(context, ref, mediaItems, index),
                child: Hero(
                  tag: 'media_${item.id}',
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      image: DecorationImage(
                        image: MemoryImage(base64Decode(item.base64Image)),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  void _showFullScreenViewer(
    BuildContext context,
    WidgetRef ref,
    List<MediaItem> items,
    int initialIndex,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) =>
                _FullScreenViewer(items: items, initialIndex: initialIndex),
      ),
    );
  }
}

class _FullScreenViewer extends StatefulWidget {
  final List<MediaItem> items;
  final int initialIndex;

  const _FullScreenViewer({required this.items, required this.initialIndex});

  @override
  State<_FullScreenViewer> createState() => _FullScreenViewerState();
}

class _FullScreenViewerState extends State<_FullScreenViewer> {
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

  Future<void> _shareImage(MediaItem item) async {
    try {
      final bytes = base64Decode(item.base64Image);
      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/shared_image_${item.timestamp.millisecondsSinceEpoch}.jpg',
      );
      await file.writeAsBytes(bytes);

      // ignore: deprecated_member_use
      await Share.shareXFiles([XFile(file.path)], text: 'Image from PocketLLM Lite');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error sharing: $e')));
      }
    }
  }

  void _goToChat(WidgetRef ref, MediaItem item) {
    final storage = ref.read(storageServiceProvider);
    final session = storage.getChatSession(item.chatId);

    if (session != null) {
      ref.read(chatProvider.notifier).loadSession(session);
      // Close viewer
      Navigator.of(context).pop();
      // Navigate to chat
      context.go('/chat');
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Chat not found')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.items[_currentIndex];
    // ignore: unused_local_variable
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.5),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat.yMMMd().add_jm().format(item.timestamp),
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            Text(
              item.chatTitle,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _shareImage(item),
          ),
          Consumer(
            builder: (context, ref, _) {
              return IconButton(
                icon: const Icon(Icons.chat),
                tooltip: 'Go to Chat',
                onPressed: () => _goToChat(ref, item),
              );
            },
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.items.length,
        onPageChanged: (index) {
          setState(() => _currentIndex = index);
        },
        itemBuilder: (context, index) {
          final currentItem = widget.items[index];
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: Hero(
                tag: 'media_${currentItem.id}',
                child: Image.memory(
                  base64Decode(currentItem.base64Image),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
