import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/providers.dart';
import '../../../chat/presentation/providers/chat_provider.dart';
import '../../domain/models/media_item.dart';

final mediaProvider = FutureProvider.autoDispose<List<MediaItem>>((ref) async {
  final storage = ref.watch(storageServiceProvider);
  return storage.getAllImages();
});

class MediaGalleryScreen extends ConsumerWidget {
  const MediaGalleryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaAsync = ref.watch(mediaProvider);
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
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No images found',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          // Group by Month
          final grouped = <String, List<MediaItem>>{};
          for (final item in items) {
            final key = DateFormat('MMMM yyyy').format(item.timestamp);
            grouped.putIfAbsent(key, () => []).add(item);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: grouped.length,
            itemBuilder: (context, index) {
              final key = grouped.keys.elementAt(index);
              final groupItems = grouped[key]!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      key,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: groupItems.length,
                    itemBuilder: (context, gridIndex) {
                      final item = groupItems[gridIndex];
                      return GestureDetector(
                        onTap: () => _showFullScreenViewer(context, ref, item),
                        child: Hero(
                          tag: item.id,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              base64Decode(item.base64Content),
                              fit: BoxFit.cover,
                              cacheWidth: 300, // Optimize memory for thumbnails
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Text('Error: $err', style: TextStyle(color: theme.colorScheme.error)),
        ),
      ),
    );
  }

  void _showFullScreenViewer(BuildContext context, WidgetRef ref, MediaItem item) {
    showDialog(
      context: context,
      useSafeArea: false,
      builder: (context) => _MediaViewerDialog(item: item),
    );
  }
}

class _MediaViewerDialog extends ConsumerWidget {
  final MediaItem item;

  const _MediaViewerDialog({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Hero(
              tag: item.id,
              child: Image.memory(
                base64Decode(item.base64Content),
                fit: BoxFit.contain,
              ),
            ),
          ),
          // Top Bar
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
                            DateFormat.yMMMd().add_jm().format(item.timestamp),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.share, color: Colors.white),
                      onPressed: () async {
                         try {
                           // Need to write to temp file to share
                           // Or use Share.shareXFiles with bytes if supported (SharePlus 10.0+ supports XFile.fromData)
                           final bytes = base64Decode(item.base64Content);
                           final xfile = XFile.fromData(
                             bytes,
                             name: 'image_${item.timestamp.millisecondsSinceEpoch}.png',
                             mimeType: 'image/png'
                           );
                           await Share.shareXFiles([xfile], text: 'Shared from PocketLLM Lite');
                         } catch (e) {
                           if (context.mounted) {
                             ScaffoldMessenger.of(context).showSnackBar(
                               SnackBar(content: Text('Error sharing: $e')),
                             );
                           }
                         }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Bottom Bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.all(16),
                color: Colors.black.withValues(alpha: 0.5),
                child: FilledButton.icon(
                  onPressed: () async {
                    final storage = ref.read(storageServiceProvider);
                    final session = storage.getChatSession(item.chatId);
                    if (session != null) {
                      Navigator.pop(context); // Close dialog
                      ref.read(chatProvider.notifier).loadSession(session);
                      context.go('/chat');
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Chat session not found')),
                      );
                    }
                  },
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Go to Chat'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
