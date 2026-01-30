import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers.dart';
import '../../../chat/presentation/providers/chat_provider.dart';
import '../../domain/models/media_item.dart';

class MediaGalleryScreen extends ConsumerStatefulWidget {
  const MediaGalleryScreen({super.key});

  @override
  ConsumerState<MediaGalleryScreen> createState() => _MediaGalleryScreenState();
}

class _MediaGalleryScreenState extends ConsumerState<MediaGalleryScreen> {
  late Future<List<MediaItem>> _imagesFuture;

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  void _loadImages() {
    final storage = ref.read(storageServiceProvider);
    // Since getAllImages is synchronous but might be heavy, we could wrap in Future
    // But getAllImages returns List<MediaItem> synchronously in current impl.
    // If we want to simulate async or if it becomes async later:
    _imagesFuture = Future.value(storage.getAllImages());
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
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
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error loading gallery: ${snapshot.error}'),
                ],
              ),
            );
          }

          final items = snapshot.data ?? [];

          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.photo_library_outlined,
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
                    'Images shared in chats will appear here',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(
                        0.7,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return _buildGallery(items);
        },
      ),
    );
  }

  Widget _buildGallery(List<MediaItem> items) {
    // Group by month
    final grouped = <String, List<MediaItem>>{};
    for (final item in items) {
      final key = DateFormat('MMMM yyyy').format(item.message.timestamp);
      grouped.putIfAbsent(key, () => []).add(item);
    }

    return CustomScrollView(
      padding: const EdgeInsets.all(4),
      slivers: [
        for (final entry in grouped.entries) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
              child: Text(
                entry.key,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
          SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              final item = entry.value[index];
              return _buildThumbnail(item);
            }, childCount: entry.value.length),
          ),
        ],
        const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
      ],
    );
  }

  Widget _buildThumbnail(MediaItem item) {
    return InkWell(
      onTap: () => _showImageViewer(item),
      child: Hero(
        tag: 'gallery_${item.message.timestamp.millisecondsSinceEpoch}_${item.base64Image.hashCode}',
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(4),
            image: DecorationImage(
              image: MemoryImage(base64Decode(item.base64Image)),
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }

  void _showImageViewer(MediaItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => Scaffold(
              backgroundColor: Colors.black,
              appBar: AppBar(
                backgroundColor: Colors.black,
                iconTheme: const IconThemeData(color: Colors.white),
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.session.title,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    Text(
                      DateFormat.yMMMd().add_jm().format(item.message.timestamp),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                actions: [
                   IconButton(
                    icon: const Icon(Icons.chat_bubble_outline),
                    tooltip: 'Go to Chat',
                    onPressed: () {
                      _navigateToChat(item);
                    },
                  ),
                ],
              ),
              body: Center(
                child: Hero(
                  tag: 'gallery_${item.message.timestamp.millisecondsSinceEpoch}_${item.base64Image.hashCode}',
                  child: InteractiveViewer(
                    child: Image.memory(base64Decode(item.base64Image)),
                  ),
                ),
              ),
            ),
      ),
    );
  }

  void _navigateToChat(MediaItem item) {
    // 1. Load session
    ref.read(chatProvider.notifier).loadSession(item.session);

    // 2. Pop viewer
    Navigator.of(context).pop();

    // 3. Navigate to chat
    // We are in /settings/gallery.
    // If we push /chat, it works.
    context.go('/chat');
  }
}
