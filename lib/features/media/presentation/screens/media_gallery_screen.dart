import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers.dart';
import '../../../../features/chat/presentation/providers/chat_provider.dart';
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              HapticFeedback.lightImpact();
              ref.invalidate(mediaGalleryProvider);
            },
          ),
        ],
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
                    'No media found',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              HapticFeedback.lightImpact();
              return ref.refresh(mediaGalleryProvider);
            },
            child: GridView.builder(
              padding: const EdgeInsets.all(4),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _showFullScreenImage(context, ref, item);
                  },
                  child: Hero(
                    tag: item.id,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        image: DecorationImage(
                          image: MemoryImage(base64Decode(item.base64Content)),
                          fit: BoxFit.cover,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Text('Error: $err', style: TextStyle(color: theme.colorScheme.error)),
        ),
      ),
    );
  }

  void _showFullScreenImage(BuildContext context, WidgetRef ref, MediaItem item) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      builder: (context) => _FullScreenImageViewer(item: item),
    );
  }
}

class _FullScreenImageViewer extends ConsumerWidget {
  final MediaItem item;

  const _FullScreenImageViewer({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat.yMMMd().add_jm().format(item.timestamp),
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            Text(
              item.sessionTitle,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
           IconButton(
            icon: const Icon(Icons.chat, color: Colors.white),
            tooltip: 'Go to Chat',
            onPressed: () async {
              HapticFeedback.mediumImpact();
              final storage = ref.read(storageServiceProvider);
              final session = storage.getChatSession(item.sessionId);
              if (session != null) {
                ref.read(chatProvider.notifier).loadSession(session);
                // Close dialog first
                Navigator.pop(context);
                 // Navigate to chat
                context.go('/chat');
              } else {
                 ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Chat session not found')),
                );
              }
            },
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
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
      ),
    );
  }
}
