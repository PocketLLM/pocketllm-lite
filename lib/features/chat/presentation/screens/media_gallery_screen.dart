import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers.dart';
import '../../../../core/utils/image_decoder.dart';
import '../../domain/models/media_item.dart';
import '../providers/chat_provider.dart';

class MediaGalleryScreen extends ConsumerStatefulWidget {
  const MediaGalleryScreen({super.key});

  @override
  ConsumerState<MediaGalleryScreen> createState() => _MediaGalleryScreenState();
}

class _MediaGalleryScreenState extends ConsumerState<MediaGalleryScreen> {
  List<MediaItem>? _mediaItems;
  List<Uint8List>? _decodedImages;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    final storage = ref.read(storageServiceProvider);
    final items = storage.getAllImages();

    // Decode images
    final base64List = items.map((e) => e.base64Content).toList();
    final decoded = await IsolateImageDecoder.decodeImages(base64List);

    if (mounted) {
      setState(() {
        _mediaItems = items;
        _decodedImages = decoded;
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
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_mediaItems == null || _mediaItems!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_not_supported_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No images found in any chat',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
        childAspectRatio: 1,
      ),
      itemCount: _mediaItems!.length,
      itemBuilder: (context, index) {
        final item = _mediaItems![index];
        final bytes = _decodedImages![index];

        return InkWell(
          onTap: () => _showFullImage(context, index),
          child: Hero(
            tag: 'gallery_${item.id}',
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                image: DecorationImage(
                  image: MemoryImage(bytes),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showFullImage(BuildContext context, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _FullScreenGalleryViewer(
          mediaItems: _mediaItems!,
          decodedImages: _decodedImages!,
          initialIndex: initialIndex,
        ),
      ),
    );
  }
}

class _FullScreenGalleryViewer extends ConsumerWidget {
  final List<MediaItem> mediaItems;
  final List<Uint8List> decodedImages;
  final int initialIndex;

  const _FullScreenGalleryViewer({
    required this.mediaItems,
    required this.decodedImages,
    required this.initialIndex,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PageController pageController = PageController(initialPage: initialIndex);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Info Button (Chat Details)
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
               final index = pageController.page?.round() ?? initialIndex;
               final item = mediaItems[index];
               _showImageDetails(context, ref, item);
            },
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: PageView.builder(
        controller: pageController,
        itemCount: mediaItems.length,
        itemBuilder: (context, index) {
          final item = mediaItems[index];
          final bytes = decodedImages[index];

          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: Hero(
                tag: 'gallery_${item.id}',
                child: Image.memory(bytes),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showImageDetails(BuildContext context, WidgetRef ref, MediaItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               Text(
                'Image Details',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline),
                title: Text(item.chatTitle),
                subtitle: const Text('Chat'),
              ),
              ListTile(
                leading: const Icon(Icons.access_time),
                title: Text(DateFormat.yMMMd().add_jm().format(item.timestamp)),
                subtitle: const Text('Sent at'),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    // Navigate to chat
                    Navigator.pop(context); // Close sheet
                    Navigator.pop(context); // Close viewer

                    final storage = ref.read(storageServiceProvider);
                    final session = storage.getChatSession(item.chatId);
                    if (session != null) {
                        ref.read(chatProvider.notifier).loadSession(session);
                        context.go('/chat');
                    } else {
                         ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Chat has been deleted')),
                        );
                    }
                  },
                  icon: const Icon(Icons.login),
                  label: const Text('Go to Chat'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
