import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';

import '../../../../core/providers.dart';
import '../../../../services/storage_service.dart';
import '../../domain/models/media_item.dart';
import '../../../chat/presentation/providers/chat_provider.dart';

class GalleryScreen extends ConsumerStatefulWidget {
  const GalleryScreen({super.key});

  @override
  ConsumerState<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends ConsumerState<GalleryScreen> {
  List<MediaItem> _mediaItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMedia();
  }

  Future<void> _loadMedia() async {
    final storage = ref.read(storageServiceProvider);
    // Use Future.microtask to avoid blocking UI during build if it's sync,
    // though getGalleryImages is sync, maybe wrap in Future if heavy?
    // For now, simple call.
    final items = storage.getGalleryImages();
    if (mounted) {
      setState(() {
        _mediaItems = items;
        _isLoading = false;
      });
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
          onPressed: () => context.pop(),
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
                        color: theme.colorScheme.outline,
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
                  padding: const EdgeInsets.all(4),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                  itemCount: _mediaItems.length,
                  itemBuilder: (context, index) {
                    final item = _mediaItems[index];
                    return _buildImageTile(context, item);
                  },
                ),
    );
  }

  Widget _buildImageTile(BuildContext context, MediaItem item) {
    return InkWell(
      onTap: () => _showImagePreview(context, item),
      child: Hero(
        tag: 'media_${item.messageTimestamp}_${item.imageIndex}',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Image.memory(
            base64Decode(item.base64Image),
            fit: BoxFit.cover,
            cacheWidth: 300, // Optimization for thumbnails
            errorBuilder: (context, error, stackTrace) => Container(
              color: Colors.grey[300],
              child: const Icon(Icons.broken_image, color: Colors.grey),
            ),
          ),
        ),
      ),
    );
  }

  void _showImagePreview(BuildContext context, MediaItem item) {
    showDialog(
      context: context,
      builder: (context) => _MediaPreviewDialog(
        item: item,
        onDelete: () => _deleteImage(item),
        onGoToChat: () => _goToChat(item),
      ),
    );
  }

  Future<void> _deleteImage(MediaItem item) async {
    final storage = ref.read(storageServiceProvider);

    // Confirm delete
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Image?'),
        content: const Text('This will remove the image from the chat history.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await storage.deleteImage(item);
      if (mounted) {
        // Refresh list
        _loadMedia();
        Navigator.pop(context); // Close preview dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image deleted')),
        );
      }
    }
  }

  void _goToChat(MediaItem item) {
    final storage = ref.read(storageServiceProvider);
    final session = storage.getChatSession(item.chatId);

    if (session != null) {
      ref.read(chatProvider.notifier).loadSession(session);
      Navigator.pop(context); // Close dialog
      // Use GoRouter to go to chat
      context.go('/chat');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chat not found')),
      );
    }
  }
}

class _MediaPreviewDialog extends StatelessWidget {
  final MediaItem item;
  final VoidCallback onDelete;
  final VoidCallback onGoToChat;

  const _MediaPreviewDialog({
    required this.item,
    required this.onDelete,
    required this.onGoToChat,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.zero,
      backgroundColor: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          InteractiveViewer(
            child: Hero(
              tag: 'media_${item.messageTimestamp}_${item.imageIndex}',
              child: Image.memory(
                base64Decode(item.base64Image),
                fit: BoxFit.contain,
              ),
            ),
          ),
          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                color: Colors.black.withValues(alpha: 0.5),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.chatTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            item.messageTimestamp.toString().split('.')[0],
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Bottom bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                color: Colors.black.withValues(alpha: 0.5),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton.icon(
                      onPressed: onGoToChat,
                      icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
                      label: const Text('Go to Chat', style: TextStyle(color: Colors.white)),
                    ),
                    TextButton.icon(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      label: const Text('Delete', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
