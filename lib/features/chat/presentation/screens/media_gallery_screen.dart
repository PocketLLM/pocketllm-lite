import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers.dart';
import '../../../../services/storage_service.dart';
import '../../domain/models/media_item.dart';
import '../providers/chat_provider.dart';

class MediaGalleryScreen extends ConsumerStatefulWidget {
  const MediaGalleryScreen({super.key});

  @override
  ConsumerState<MediaGalleryScreen> createState() => _MediaGalleryScreenState();
}

class _MediaGalleryScreenState extends ConsumerState<MediaGalleryScreen> {
  List<MediaItem>? _mediaItems;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMedia();
  }

  Future<void> _loadMedia() async {
    final storage = ref.read(storageServiceProvider);
    // Add small delay to ensure UI builds first
    await Future.delayed(Duration.zero);

    // Get all images (this might be heavy, but for MVP it's okay)
    final items = storage.getAllImages();

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
          : _mediaItems == null || _mediaItems!.isEmpty
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
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Images you send or receive will appear here',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                          fontSize: 14,
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
                  itemCount: _mediaItems!.length,
                  itemBuilder: (context, index) {
                    final item = _mediaItems![index];
                    return GestureDetector(
                      onTap: () => _showImagePreview(context, item),
                      onLongPress: () => _showOptions(context, item),
                      child: Hero(
                        tag: 'media_${item.id}',
                        child: Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            image: DecorationImage(
                              image: MemoryImage(
                                base64Decode(item.base64Image),
                              ),
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

  void _showImagePreview(BuildContext context, MediaItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            title: Text(
              DateFormat.yMMMd().add_jm().format(item.timestamp),
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline),
                tooltip: 'Go to Chat',
                onPressed: () {
                  Navigator.pop(context);
                  _navigateToChat(item);
                },
              ),
            ],
          ),
          body: Center(
            child: Hero(
              tag: 'media_${item.id}',
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.memory(
                  base64Decode(item.base64Image),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showOptions(BuildContext context, MediaItem item) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: const Text('Go to Chat'),
              onTap: () {
                Navigator.pop(context);
                _navigateToChat(item);
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Details'),
              subtitle: Text(DateFormat.yMMMMEEEEd().add_jm().format(item.timestamp)),
              onTap: null, // Just info
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToChat(MediaItem item) {
    final storage = ref.read(storageServiceProvider);
    final session = storage.getChatSession(item.chatId);

    if (session == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chat containing this image has been deleted')),
      );
      return;
    }

    HapticFeedback.lightImpact();
    ref.read(chatProvider.notifier).loadSession(session);
    context.go('/chat');
  }
}
