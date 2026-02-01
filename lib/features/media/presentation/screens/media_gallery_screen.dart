import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers.dart';
import '../../../../services/storage_service.dart';
import '../../domain/models/media_item.dart';
import '../../../chat/presentation/providers/chat_provider.dart';

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
    // Run on microtask to avoid blocking UI build
    Future.microtask(() {
      final storage = ref.read(storageServiceProvider);
      final images = storage.getAllImages();
      if (mounted) {
        setState(() {
          _images = images;
          _isLoading = false;
        });
      }
    });
  }

  void _openImage(MediaItem item) {
    showDialog(
      context: context,
      builder: (context) => _FullScreenImageViewer(item: item),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                      const Icon(Icons.image_not_supported_outlined,
                          size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        'No images found in chats',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.grey,
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
                      onTap: () => _openImage(item),
                      child: Hero(
                        tag: item.id,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            base64Decode(item.base64Content),
                            fit: BoxFit.cover,
                            cacheWidth: 300, // Optimization
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
    return Dialog(
      insetPadding: EdgeInsets.zero,
      backgroundColor: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          InteractiveViewer(
            child: Hero(
              tag: item.id,
              child: Image.memory(
                base64Decode(item.base64Content),
                fit: BoxFit.contain,
              ),
            ),
          ),
          Positioned(
            top: 40,
            right: 20,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
                  tooltip: 'Jump to Chat',
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    _jumpToChat(context, ref, item.chatId);
                  },
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black54,
                  ),
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
           Positioned(
            bottom: 40,
            left: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _formatDate(item.timestamp),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _jumpToChat(BuildContext context, WidgetRef ref, String chatId) {
    final storage = ref.read(storageServiceProvider);
    final session = storage.getChatSession(chatId);
    if (session != null) {
      ref.read(chatProvider.notifier).loadSession(session);
      // We are likely in Settings -> Media Gallery.
      // We want to go to /chat.
      context.go('/chat');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chat not found (might be deleted)')),
      );
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
