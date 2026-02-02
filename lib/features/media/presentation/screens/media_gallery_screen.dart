import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

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
    _loadMedia();
  }

  Future<void> _loadMedia() async {
    // Run on post frame callback to ensure provider is ready if needed,
    // though usually fine in initState for reading.
    // Using Future.microtask to avoid blocking UI thread immediately if possible,
    // though Hive is sync/async.
    final storage = ref.read(storageServiceProvider);

    // Defer the heavy lifting slightly or rely on the sync nature of Hive
    // getAllImages iterates all chats, might be slow if many chats.
    // Ideally should be done in isolate, but for now we run it here.
    final items = await Future.microtask(() => storage.getAllImages());

    if (mounted) {
      setState(() {
        _mediaItems = items;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Media Gallery'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _mediaItems.isEmpty
              ? _buildEmptyState()
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
                    return _buildGridItem(context, item);
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_not_supported_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No images found in chats',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridItem(BuildContext context, MediaItem item) {
    // Decoding here might be expensive for list, but Image.memory handles it.
    // For smoother scrolling, we could optimize, but Image.memory with cacheWidth helps.
    Uint8List bytes;
    try {
       bytes = base64Decode(item.base64Content);
    } catch (e) {
       return const SizedBox.shrink();
    }

    return InkWell(
      onTap: () => _openDetail(context, item, bytes),
      child: Hero(
        tag: 'media_${item.hashCode}',
        child: Container(
          decoration: const BoxDecoration(
             color: Colors.black12,
          ),
          child: Image.memory(
            bytes,
            fit: BoxFit.cover,
            cacheWidth: 300, // Optimization for grid thumbnail
          ),
        ),
      ),
    );
  }

  void _openDetail(BuildContext context, MediaItem item, Uint8List bytes) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _MediaDetailScreen(item: item, bytes: bytes),
      ),
    );
  }
}

class _MediaDetailScreen extends ConsumerWidget {
  final MediaItem item;
  final Uint8List bytes;

  const _MediaDetailScreen({required this.item, required this.bytes});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            tooltip: 'View in Chat',
            onPressed: () => _jumpToChat(context, ref),
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Center(
        child: Hero(
          tag: 'media_${item.hashCode}',
          child: InteractiveViewer(
            child: Image.memory(bytes),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        color: Colors.black54,
        padding: const EdgeInsets.all(16),
        child: SafeArea(
          child: Text(
            DateFormat.yMMMd().add_jm().format(item.timestamp),
            style: const TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Future<void> _jumpToChat(BuildContext context, WidgetRef ref) async {
    HapticFeedback.selectionClick();
    final storage = ref.read(storageServiceProvider);
    final session = storage.getChatSession(item.chatId);

    if (session != null) {
      ref.read(chatProvider.notifier).loadSession(session);

      // Close detail screen first
      Navigator.pop(context);

      // Navigate to chat
      // Using context.go to ensure we switch to the chat tab/route properly
      if (context.mounted) {
         context.go('/chat');
      }
    } else {
        if(context.mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Chat not found (might have been deleted)'),
                    backgroundColor: Colors.red,
                ),
            );
        }
    }
  }
}
