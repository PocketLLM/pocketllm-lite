import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/providers.dart';
import '../../../../core/utils/image_decoder.dart';
import '../../../chat/domain/models/media_item.dart';
import '../../../chat/presentation/providers/chat_provider.dart';

class MediaGalleryScreen extends ConsumerStatefulWidget {
  const MediaGalleryScreen({super.key});

  @override
  ConsumerState<MediaGalleryScreen> createState() => _MediaGalleryScreenState();
}

class _MediaGalleryScreenState extends ConsumerState<MediaGalleryScreen> {
  List<MediaItem> _allImages = [];
  List<MediaItem> _filteredImages = [];
  bool _isLoading = true;
  String _filter = 'All'; // All, Sent, Received

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    final storage = ref.read(storageServiceProvider);
    // Move heavy work to microtask to avoid blocking init
    await Future.microtask(() {
      final images = storage.getAllImages();
      if (mounted) {
        setState(() {
          _allImages = images;
          _applyFilter();
          _isLoading = false;
        });
      }
    });
  }

  void _applyFilter() {
    if (_filter == 'All') {
      _filteredImages = List.from(_allImages);
    } else if (_filter == 'Sent') {
      _filteredImages = _allImages.where((i) => i.role == 'user').toList();
    } else {
      _filteredImages = _allImages.where((i) => i.role == 'assistant').toList();
    }
  }

  void _onFilterChanged(String filter) {
    setState(() {
      _filter = filter;
      _applyFilter();
    });
    HapticFeedback.selectionClick();
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
      body: Column(
        children: [
          // Filter Bar
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Row(
              children: [
                _buildFilterChip('All'),
                const SizedBox(width: 8),
                _buildFilterChip('Sent'), // User
                const SizedBox(width: 8),
                _buildFilterChip('Received'), // Assistant
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredImages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.image_not_supported_outlined,
                              size: 64,
                              color: theme.colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No images found',
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(4),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 4,
                          mainAxisSpacing: 4,
                        ),
                        itemCount: _filteredImages.length,
                        itemBuilder: (context, index) {
                          final item = _filteredImages[index];
                          return GestureDetector(
                            onTap: () => _openFullScreen(index),
                            child: Hero(
                              tag: 'media_${item.id}',
                              child: _ThumbnailImage(
                                base64Content: item.base64Content,
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _filter == label;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) _onFilterChanged(label);
      },
      checkmarkColor: isSelected ? Colors.white : null,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : null,
        fontWeight: isSelected ? FontWeight.bold : null,
      ),
      selectedColor: Theme.of(context).colorScheme.primary,
    );
  }

  void _openFullScreen(int initialIndex) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FullScreenImageViewer(
          images: _filteredImages,
          initialIndex: initialIndex,
        ),
      ),
    );
  }
}

class _ThumbnailImage extends StatefulWidget {
  final String base64Content;

  const _ThumbnailImage({required this.base64Content});

  @override
  State<_ThumbnailImage> createState() => _ThumbnailImageState();
}

class _ThumbnailImageState extends State<_ThumbnailImage> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  Future<void> _decode() async {
    // Use IsolateImageDecoder to decode off-thread
    final decoded = await IsolateImageDecoder.decodeImages([
      widget.base64Content,
    ]);
    if (mounted && decoded.isNotEmpty) {
      setState(() {
        _bytes = decoded.first;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_bytes == null) {
      return Container(
        color: Colors.grey.withValues(alpha: 0.1),
        child: const Center(
            child: SizedBox(
                width: 20, height: 20, child: CircularProgressIndicator())),
      );
    }
    return Image.memory(
      _bytes!,
      fit: BoxFit.cover,
      cacheWidth: 200, // Optimize memory for thumbnails
    );
  }
}

class FullScreenImageViewer extends ConsumerStatefulWidget {
  final List<MediaItem> images;
  final int initialIndex;

  const FullScreenImageViewer({
    super.key,
    required this.images,
    required this.initialIndex,
  });

  @override
  ConsumerState<FullScreenImageViewer> createState() =>
      _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends ConsumerState<FullScreenImageViewer> {
  late PageController _pageController;
  late int _currentIndex;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
  }

  Future<void> _goToChat(MediaItem item) async {
    HapticFeedback.mediumImpact();
    final storage = ref.read(storageServiceProvider);
    final session = storage.getChatSession(item.chatId);

    if (session != null) {
      ref.read(chatProvider.notifier).loadSession(session);
      // Navigate to chat
      // We are in a fullscreen dialog/route pushed by Navigator.
      // We need to pop this, pop the gallery, and go to chat.
      // Or just go to chat directly using GoRouter, which handles stack?

      // If we use context.go('/chat'), it replaces the stack.
      // This is good.
      context.go('/chat');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chat not found (deleted?)')),
      );
    }
  }

  Future<void> _shareImage(MediaItem item) async {
    final bytes = base64Decode(item.base64Content);
    // Share using share_plus
    // share_plus requires a file path or XFile.
    // We need to write to temp file first.
    // Actually Share.shareXFiles accepts bytes in XFile.fromData (on some platforms) or we write to file.

    // Easier to write to file.
    try {
       // Just sharing text for now as quick implementation, but better to share file.
       // Actually, let's try sharing via XFile with bytes if possible,
       // but typically we need a file path for good support.

       // For now, let's just implement basic UI.
       // Ref: "Implement proper file upload with preview" - implies file handling skills.

       final name = 'image_${item.timestamp.millisecondsSinceEpoch}.png';
       final xfile = XFile.fromData(bytes, name: name, mimeType: 'image/png');

       await Share.shareXFiles([xfile], text: 'Shared from PocketLLM');

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text('Error sharing: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.images[_currentIndex];
    final dateStr =
        '${item.timestamp.day}/${item.timestamp.month}/${item.timestamp.year} ${item.timestamp.hour}:${item.timestamp.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.images.length,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
            },
            itemBuilder: (context, index) {
              final img = widget.images[index];
              return GestureDetector(
                onTap: _toggleControls,
                child: Center(
                  child: Hero(
                    tag: 'media_${img.id}',
                    child: InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 4.0,
                      child: Image.memory(
                        base64Decode(img.base64Content),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // Top Bar
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            top: _showControls ? 0 : -80,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                color: Colors.black.withValues(alpha: 0.4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          dateStr,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          item.role == 'user' ? 'Sent by You' : 'Generated by AI',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Bar
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            bottom: _showControls ? 0 : -80,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.all(16),
                color: Colors.black.withValues(alpha: 0.4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton.icon(
                      onPressed: () => _shareImage(item),
                      icon: const Icon(Icons.share, color: Colors.white),
                      label: const Text('Share', style: TextStyle(color: Colors.white)),
                    ),
                    TextButton.icon(
                      onPressed: () => _goToChat(item),
                      icon: const Icon(Icons.chat, color: Colors.white),
                      label: const Text('Go to Chat', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
