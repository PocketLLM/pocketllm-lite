import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../../core/providers.dart';
import '../../../chat/domain/models/chat_session.dart';

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
          final sessions = storage.getChatSessions();
          final mediaItems = <_MediaItem>[];

          for (final session in sessions) {
            if (chatId != null && session.id != chatId) continue;
            for (final message in session.messages) {
              final images = message.images;
              if (images == null || images.isEmpty) continue;
              for (final image in images) {
                mediaItems.add(
                  _MediaItem(
                    chatId: session.id,
                    chatTitle: session.title,
                    timestamp: message.timestamp,
                    base64: image,
                  ),
                );
              }
            }
          }

          if (mediaItems.isEmpty) {
            return Center(
              child: Text(
                'No images yet.',
                style: Theme.of(context).textTheme.bodyMedium,
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
                onTap: () => _showViewer(context, bytes, item),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    bytes,
                    fit: BoxFit.cover,
                    cacheWidth: 300,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showViewer(
    BuildContext context,
    Uint8List bytes,
    _MediaItem item,
  ) {
    final height = MediaQuery.of(context).size.height * 0.8;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(16),
        child: SizedBox(
          height: height,
          child: Column(
            children: [
              Expanded(
                child: InteractiveViewer(
                  child: Image.memory(bytes, fit: BoxFit.contain),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                width: double.infinity,
                color: Colors.black87,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.chatTitle,
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.timestamp.toLocal().toString(),
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MediaItem {
  final String chatId;
  final String chatTitle;
  final DateTime timestamp;
  final String base64;

  const _MediaItem({
    required this.chatId,
    required this.chatTitle,
    required this.timestamp,
    required this.base64,
  });
}
