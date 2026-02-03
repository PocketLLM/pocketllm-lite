import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../../core/providers.dart';
import '../../../chat/domain/models/chat_session.dart';
import 'full_screen_image_viewer.dart';

class MediaGalleryScreen extends ConsumerWidget {
  final String? chatId;
  final String? chatTitle;

  const MediaGalleryScreen({super.key, this.chatId, this.chatTitle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(storageServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(chatTitle != null ? 'Media: $chatTitle' : 'Media Gallery'),
      ),
      body: ValueListenableBuilder<Box<ChatSession>>(
        valueListenable: storage.chatBoxListenable,
        builder: (context, box, _) {
          final mediaItems = storage.getAllImages(chatId: chatId);

          if (mediaItems.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.photo_library_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No images found',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: mediaItems.length,
            itemBuilder: (context, index) {
              final item = mediaItems[index];
              final bytes = base64Decode(item.base64);
              return GestureDetector(
                onTap:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => FullScreenImageViewer(
                              mediaItems: mediaItems,
                              initialIndex: index,
                            ),
                      ),
                    ),
                child: Hero(
                  tag: 'image_${item.timestamp.millisecondsSinceEpoch}',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      bytes,
                      fit: BoxFit.cover,
                      cacheWidth: 300,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
