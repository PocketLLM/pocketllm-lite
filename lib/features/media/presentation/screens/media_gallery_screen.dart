import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/image_decoder.dart';
import '../../../../core/providers.dart';
import '../../../chat/presentation/providers/chat_provider.dart';
import '../../domain/models/media_item.dart';
import '../providers/media_provider.dart';

class MediaGalleryScreen extends ConsumerWidget {
  const MediaGalleryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaAsync = ref.watch(mediaGalleryProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Media Gallery'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            HapticFeedback.selectionClick();
            context.pop();
          },
        ),
      ),
      body: mediaAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.image_not_supported_outlined,
                    size: 64,
                    color: theme.colorScheme.outline.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No media found',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(4),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = items[index];
                      return MediaGridItem(
                        item: item,
                        onTap: (bytes) {
                          _showFullScreenImage(context, ref, item, bytes);
                        },
                      );
                    },
                    childCount: items.length,
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text(
            'Error loading gallery: $error',
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ),
      ),
    );
  }

  void _showFullScreenImage(
    BuildContext context,
    WidgetRef ref,
    MediaItem item,
    Uint8List bytes,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => Scaffold(
              backgroundColor: Colors.black,
              appBar: AppBar(
                backgroundColor: Colors.black,
                iconTheme: const IconThemeData(color: Colors.white),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.chat),
                    tooltip: 'Jump to Chat',
                    onPressed: () {
                      _jumpToChat(context, ref, item.chatId);
                    },
                  ),
                ],
              ),
              body: Center(
                child: InteractiveViewer(
                  child: Hero(
                    tag: 'media_${item.id}',
                    child: Image.memory(bytes),
                  ),
                ),
              ),
            ),
      ),
    );
  }

  void _jumpToChat(BuildContext context, WidgetRef ref, String chatId) {
    final storage = ref.read(storageServiceProvider);
    final session = storage.getChatSession(chatId);

    if (session != null) {
      // Load session into provider
      ref.read(chatProvider.notifier).loadSession(session);

      // Go to chat screen
      context.go('/chat');
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Chat not found')));
    }
  }
}

class MediaGridItem extends StatefulWidget {
  final MediaItem item;
  final Function(Uint8List) onTap;

  const MediaGridItem({super.key, required this.item, required this.onTap});

  @override
  State<MediaGridItem> createState() => _MediaGridItemState();
}

class _MediaGridItemState extends State<MediaGridItem> {
  Uint8List? _bytes;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void didUpdateWidget(MediaGridItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item != widget.item) {
        _decode();
    }
  }

  Future<void> _decode() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final results = await IsolateImageDecoder.decodeImages([widget.item.base64Content]);
      if (mounted && results.isNotEmpty) {
        setState(() {
          _bytes = results.first;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
         setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }

    if (_bytes == null) {
        return Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Icon(Icons.broken_image, size: 24),
        );
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        if (_bytes != null) widget.onTap(_bytes!);
      },
      child: Hero(
        tag: 'media_${widget.item.id}', // Use unique ID for Hero
        child: Container(
            decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.2)),
            ),
            child: Image.memory(
              _bytes!,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
        ),
      ),
    );
  }
}
