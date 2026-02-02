import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers.dart';
import '../../../../features/chat/presentation/providers/chat_provider.dart';
import '../../domain/models/media_item.dart';

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
    // Adding a slight delay to unblock UI if synchronous
    await Future.delayed(Duration.zero);
    if (!mounted) return;
    final storage = ref.read(storageServiceProvider);
    final images = storage.getAllImages();
    if (mounted) {
      setState(() {
        _images = images;
        _isLoading = false;
      });
    }
  }

  void _showImageDialog(BuildContext context, MediaItem item) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.9), // Darker background
      builder: (context) => _FullScreenImageViewer(item: item),
    );
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
          : _images.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.image_not_supported_outlined,
                        size: 64,
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.5,
                        ),
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
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(4),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                  itemCount: _images.length,
                  itemBuilder: (context, index) {
                    final item = _images[index];
                    return GestureDetector(
                      onTap: () => _showImageDialog(context, item),
                      child: Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                          image: DecorationImage(
                            image: MemoryImage(
                              base64Decode(item.base64Content),
                            ),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class _FullScreenImageViewer extends ConsumerWidget {
  final MediaItem item;

  const _FullScreenImageViewer({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dateStr = DateFormat('MMM d, y • HH:mm').format(item.timestamp);

    final storage = ref.read(storageServiceProvider);
    final session = storage.getChatSession(item.chatId);
    final chatTitle = session?.title ?? 'Unknown Chat';

    return Stack(
      children: [
        InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Center(
            child: Image.memory(
              base64Decode(item.base64Content),
              fit: BoxFit.contain,
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
             padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
             color: Colors.black.withValues(alpha: 0.5),
             child: Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                 IconButton(
                   icon: const Icon(Icons.close, color: Colors.white),
                   onPressed: () => Navigator.pop(context),
                 ),
                 Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          chatTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            decoration: TextDecoration.none,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          dateStr,
                          style: const TextStyle(
                            color: Colors.white70,
                             fontSize: 12,
                             decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                 ),
               ],
             ),
          ),
        ),
        Positioned(
          bottom: 24,
          left: 16,
          right: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
               ElevatedButton.icon(
                 onPressed: () async {
                   Navigator.pop(context); // Close dialog

                   if (session != null) {
                     await ref.read(chatProvider.notifier).loadSession(session);
                     if (context.mounted) {
                       context.go('/chat');
                     }
                   } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                           const SnackBar(content: Text('Chat session not found')),
                        );
                      }
                   }
                 },
                 icon: const Icon(Icons.chat_bubble_outline),
                 label: const Text('Go to Chat'),
                 style: ElevatedButton.styleFrom(
                   backgroundColor: theme.colorScheme.primary,
                   foregroundColor: theme.colorScheme.onPrimary,
                 ),
               ),
            ],
          ),
        ),
      ],
    );
  }
}
