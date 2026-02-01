import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/providers.dart';
import '../../../../features/chat/domain/models/chat_session.dart';
import '../../domain/models/media_item.dart';
import '../../../chat/presentation/providers/chat_provider.dart';

class MediaGalleryScreen extends ConsumerStatefulWidget {
  const MediaGalleryScreen({super.key});

  @override
  ConsumerState<MediaGalleryScreen> createState() => _MediaGalleryScreenState();
}

class _MediaGalleryScreenState extends ConsumerState<MediaGalleryScreen> {
  List<MediaItem> _allImages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    final storage = ref.read(storageServiceProvider);
    final images = storage.getAllImages();
    if (mounted) {
      setState(() {
        _allImages = images;
        _isLoading = false;
      });
    }
  }

  void _openImage(BuildContext context, MediaItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _MediaDetailScreen(item: item),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Media Gallery')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_allImages.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Media Gallery')),
        body: Center(
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
                'Images shared in chats will appear here',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Group images by date
    final groupedImages = <String, List<MediaItem>>{};
    for (final item in _allImages) {
      final dateKey = _getDateKey(item.timestamp);
      groupedImages.putIfAbsent(dateKey, () => []).add(item);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Media Gallery'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${_allImages.length} images',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: groupedImages.entries.map((entry) {
          return SliverMainAxisGroup(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    entry.key,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = entry.value[index];
                      return _MediaGridItem(
                        item: item,
                        onTap: () => _openImage(context, item),
                      );
                    },
                    childCount: entry.value.length,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  String _getDateKey(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final itemDate = DateTime(date.year, date.month, date.day);

    if (itemDate == today) return 'Today';
    if (itemDate == yesterday) return 'Yesterday';
    return DateFormat.yMMMd().format(date);
  }
}

class _MediaGridItem extends StatelessWidget {
  final MediaItem item;
  final VoidCallback onTap;

  const _MediaGridItem({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    Uint8List? imageBytes;
    try {
      imageBytes = base64Decode(item.imagePath);
    } catch (e) {
      // Handle error
    }

    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.antiAlias,
        child: imageBytes != null
            ? Image.memory(
                imageBytes,
                fit: BoxFit.cover,
                cacheWidth: 200, // Optimization
              )
            : const Icon(Icons.broken_image),
      ),
    );
  }
}

class _MediaDetailScreen extends ConsumerWidget {
  final MediaItem item;

  const _MediaDetailScreen({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Uint8List? imageBytes;
    try {
      imageBytes = base64Decode(item.imagePath);
    } catch (e) {
      // Handle error
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
           TextButton.icon(
            onPressed: () {
               _goToChat(context, ref);
            },
             icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
             label: const Text('Go to Chat', style: TextStyle(color: Colors.white)),
           ),
        ],
      ),
      body: Center(
        child: imageBytes != null
            ? InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.memory(imageBytes),
              )
            : const Icon(Icons.broken_image, color: Colors.white, size: 64),
      ),
      bottomSheet: Container(
        color: Colors.black.withOpacity(0.7),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              item.chatTitle,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat.yMMMd().add_jm().format(item.timestamp),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _goToChat(BuildContext context, WidgetRef ref) {
    final storage = ref.read(storageServiceProvider);
    final session = storage.getChatSession(item.chatId);

    if (session != null) {
      ref.read(chatProvider.notifier).loadSession(session);
      // Pop detail screen
      Navigator.of(context).pop();
      // Check if we are in History screen or elsewhere.
      // If we pushed from History, we might need to pop History too to go to ChatScreen?
      // Actually ChatScreen is usually the root or navigated to.
      // If we are in ChatHistoryScreen, popping MediaGalleryScreen returns to History.
      // We want to go to ChatScreen.

      // Assuming ChatScreen is the main route '/chat' or similar.
      // But loadSession updates state. If we just pop everything back to root?

      // Let's assume standard navigation:
      // ChatScreen -> ChatHistory -> MediaGallery -> Detail
      // We want to go back to ChatScreen.
      // So we popUntil... or just pop 3 times?

      // Better: Use GoRouter if available, or just pop until first route?
      // But ChatScreen might not be in stack if we are in a different flow.

      // Simplest: Pop everything until we are back at ChatScreen.
      // Since ChatScreen pushes History, and History pushes Gallery.
      // popping 3 times might work.

      // Or just Navigator.of(context).popUntil((route) => route.isFirst);
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }
}
