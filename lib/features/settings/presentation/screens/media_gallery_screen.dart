import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/providers.dart';
import '../../domain/models/media_item.dart';
import '../../../../services/storage_service.dart';

class MediaGalleryScreen extends ConsumerStatefulWidget {
  const MediaGalleryScreen({super.key});

  @override
  ConsumerState<MediaGalleryScreen> createState() => _MediaGalleryScreenState();
}

class _MediaGalleryScreenState extends ConsumerState<MediaGalleryScreen> {
  List<MediaItem> _mediaItems = [];
  bool _isLoading = true;
  bool _isSelectionMode = false;
  final Set<MediaItem> _selectedItems = {};

  @override
  void initState() {
    super.initState();
    _loadMedia();
  }

  Future<void> _loadMedia() async {
    final storage = ref.read(storageServiceProvider);
    // Add delay to allow UI to settle
    await Future.delayed(Duration.zero);

    final items = storage.getAllMedia();

    if (mounted) {
      setState(() {
        _mediaItems = items;
        _isLoading = false;
        _selectedItems.clear();
        _isSelectionMode = false;
      });
    }
  }

  Future<void> _deleteSelected() async {
    final count = _selectedItems.length;
    if (count == 0) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $count images?'),
        content: const Text('This will remove these images from their chats. If a message becomes empty, it will be deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      final storage = ref.read(storageServiceProvider);
      await storage.deleteMedia(_selectedItems.toList());

      HapticFeedback.mediumImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted $count images')),
        );
        _loadMedia();
      }
    }
  }

  void _toggleSelection(MediaItem item) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedItems.contains(item)) {
        _selectedItems.remove(item);
        if (_selectedItems.isEmpty) _isSelectionMode = false;
      } else {
        _selectedItems.add(item);
        _isSelectionMode = true;
      }
    });
  }

  void _showImageViewer(MediaItem item) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.memory(
                base64Decode(item.base64Content),
                fit: BoxFit.contain,
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(12),
                color: Colors.black54,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.chatTitle,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      DateFormat.yMMMd().add_jm().format(item.messageTimestamp),
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: !_isSelectionMode,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        setState(() {
          _isSelectionMode = false;
          _selectedItems.clear();
        });
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isSelectionMode ? '${_selectedItems.length} Selected' : 'Media Gallery'),
          leading: _isSelectionMode
              ? IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      _isSelectionMode = false;
                      _selectedItems.clear();
                    });
                  },
                )
              : IconButton(
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
            if (_isSelectionMode)
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: _selectedItems.isEmpty ? null : _deleteSelected,
              ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _mediaItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.image_not_supported_outlined, size: 64, color: theme.colorScheme.outline),
                        const SizedBox(height: 16),
                        Text('No media found', style: theme.textTheme.titleMedium),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: _mediaItems.length,
                    itemBuilder: (context, index) {
                      final item = _mediaItems[index];
                      final isSelected = _selectedItems.contains(item);

                      return GestureDetector(
                        onTap: () {
                          if (_isSelectionMode) {
                            _toggleSelection(item);
                          } else {
                            _showImageViewer(item);
                          }
                        },
                        onLongPress: () => _toggleSelection(item),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(
                                base64Decode(item.base64Content),
                                fit: BoxFit.cover,
                                cacheWidth: 200, // Optimize memory for thumbnails
                              ),
                            ),
                            if (_isSelectionMode)
                              Container(
                                decoration: BoxDecoration(
                                  color: isSelected ? theme.colorScheme.primary.withValues(alpha: 0.4) : Colors.black.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: isSelected ? Border.all(color: theme.colorScheme.primary, width: 3) : null,
                                ),
                                child: isSelected
                                    ? Icon(Icons.check_circle, color: theme.colorScheme.primary, size: 24)
                                    : const Align(
                                        alignment: Alignment.topRight,
                                        child: Padding(
                                          padding: EdgeInsets.all(4),
                                          child: Icon(Icons.circle_outlined, color: Colors.white, size: 24),
                                        ),
                                      ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
