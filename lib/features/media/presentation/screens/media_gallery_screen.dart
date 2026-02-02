import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers.dart';
import '../../domain/models/media_item.dart';

class MediaGalleryScreen extends ConsumerStatefulWidget {
  const MediaGalleryScreen({super.key});

  @override
  ConsumerState<MediaGalleryScreen> createState() => _MediaGalleryScreenState();
}

class _MediaGalleryScreenState extends ConsumerState<MediaGalleryScreen> {
  List<MediaItem>? _images;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    // Run on next frame to avoid provider issues if any
    await Future.delayed(Duration.zero);
    if (!mounted) return;

    final storage = ref.read(storageServiceProvider);

    // Defer execution to ensure UI remains responsive if large dataset
    final images = await Future.microtask(() => storage.getAllImages());

    if (mounted) {
      setState(() {
        _images = images;
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
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _images == null || _images!.isEmpty
              ? Center(
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
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
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
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(4),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                  itemCount: _images!.length,
                  itemBuilder: (context, index) {
                    final item = _images![index];
                    return GestureDetector(
                      onTap: () {
                         context.go(
                          '/settings/media-gallery/preview',
                          extra: {'images': _images!, 'initialIndex': index},
                        );
                      },
                      child: Hero(
                        tag: item.id,
                        child: Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.memory(
                              base64Decode(item.base64Data),
                              fit: BoxFit.cover,
                              cacheWidth: (150 * MediaQuery.of(context).devicePixelRatio).round(),
                              errorBuilder: (context, error, stackTrace) {
                                return Center(
                                  child: Icon(
                                    Icons.broken_image,
                                    color: theme.colorScheme.error
                                  )
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
