import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/providers.dart';
import '../../../chat/presentation/providers/chat_provider.dart';
import '../../domain/models/media_item.dart';

class FullScreenImageViewer extends ConsumerStatefulWidget {
  final List<MediaItem> mediaItems;
  final int initialIndex;

  const FullScreenImageViewer({
    super.key,
    required this.mediaItems,
    required this.initialIndex,
  });

  @override
  ConsumerState<FullScreenImageViewer> createState() =>
      _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends ConsumerState<FullScreenImageViewer> {
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
      final bytes = base64Decode(item.base64);
      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/image_${item.timestamp.millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Image from PocketLLM: ${item.chatTitle}',
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share image: $e')),
        );
      }
    }
  }

  Future<void> _jumpToChat(MediaItem item) async {
    final storage = ref.read(storageServiceProvider);
    final session = storage.getChatSession(item.chatId);
    if (session != null) {
      HapticFeedback.mediumImpact();
      ref.read(chatProvider.notifier).loadSession(session);
      // Navigate to chat
      context.go('/chat');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chat session not found')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentItem = widget.mediaItems[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.5),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              currentItem.chatTitle,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${_currentIndex + 1} of ${widget.mediaItems.length}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            tooltip: 'Jump to Chat',
            onPressed: () => _jumpToChat(currentItem),
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share',
            onPressed: () => _shareImage(currentItem),
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.mediaItems.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemBuilder: (context, index) {
          final item = widget.mediaItems[index];
          final bytes = base64Decode(item.base64);

          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(child: Image.memory(bytes, fit: BoxFit.contain)),
          );
        },
      ),
    );
  }
}
