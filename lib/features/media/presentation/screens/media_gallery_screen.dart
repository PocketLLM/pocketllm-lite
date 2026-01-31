import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers.dart';
import '../../domain/models/media_item.dart';
import '../../../chat/presentation/providers/chat_provider.dart';

class MediaGalleryScreen extends ConsumerStatefulWidget {
  const MediaGalleryScreen({super.key});

  @override
  ConsumerState<MediaGalleryScreen> createState() => _MediaGalleryScreenState();
}

class _MediaGalleryScreenState extends ConsumerState<MediaGalleryScreen> {
  List<MediaItem> _mediaItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Fetch images after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadImages();
    });
  }

  Future<void> _loadImages() async {
    // Run on microtask to avoid blocking UI immediately if sync
    await Future.delayed(Duration.zero);
    if (!mounted) return;

    final storage = ref.read(storageServiceProvider);
    final images = storage.getAllImages();

    setState(() {
      _mediaItems = images;
      _isLoading = false;
    });
  }

  void _showFullImage(MediaItem item) {
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
                child: Image.memory(
                  base64Decode(item.base64),
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              top: 16,
              left: 16,
              child: SafeArea(
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black54,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Center(
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context); // Close dialog
                      _jumpToChat(item.chatId);
                    },
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Go to Chat'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _jumpToChat(String chatId) {
    final storage = ref.read(storageServiceProvider);
    final session = storage.getChatSession(chatId);

    if (session != null) {
      ref.read(chatProvider.notifier).loadSession(session);

      // Navigate to chat.
      // If we are in /settings/media-gallery, we need to go to /chat.
      // GoRouter handles the stack.
      context.go('/chat');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chat not found (might be deleted)')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _mediaItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.image_not_supported_outlined,
                        size: 64,
                        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No images found',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Images sent in chats will appear here',
                        style: theme.textTheme.bodyMedium?.copyWith(
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
                  itemCount: _mediaItems.length,
                  itemBuilder: (context, index) {
                    final item = _mediaItems[index];
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _showFullImage(item);
                      },
                      child: Hero(
                        tag: item.id,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: theme.colorScheme.surfaceContainerHighest,
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Image.memory(
                            base64Decode(item.base64),
                            fit: BoxFit.cover,
                            cacheWidth: 200, // Optimize memory for grid
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
