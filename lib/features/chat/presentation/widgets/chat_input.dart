import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers.dart';
import '../providers/chat_provider.dart';

class ChatInput extends ConsumerStatefulWidget {
  const ChatInput({super.key});

  @override
  ConsumerState<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends ConsumerState<ChatInput> {
  final _controller = TextEditingController();
  final _picker = ImagePicker();
  final List<String> _selectedImages = [];

  Future<void> _pickImage() async {
    // Show bottom sheet to choose camera or gallery
    final storage = ref.read(storageServiceProvider);
    if (storage.getSetting(
      AppConstants.hapticFeedbackKey,
      defaultValue: false,
    )) {
      HapticFeedback.selectionClick();
    }

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source != null) {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        final base64 = base64Encode(bytes);
        setState(() {
          _selectedImages.add(base64);
        });
      }
    }
  }

  void _send() {
    if (_controller.text.trim().isEmpty && _selectedImages.isEmpty) return;

    final storage = ref.read(storageServiceProvider);
    if (storage.getSetting(
      AppConstants.hapticFeedbackKey,
      defaultValue: false,
    )) {
      HapticFeedback.lightImpact();
    }

    ref
        .read(chatProvider.notifier)
        .sendMessage(
          _controller.text,
          images: _selectedImages.isNotEmpty ? [..._selectedImages] : null,
        );

    _controller.clear();
    setState(() {
      _selectedImages.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isGenerating = ref.watch(chatProvider.select((s) => s.isGenerating));
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface, // Background of the bar area
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF0F2F5),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? Colors.grey[800]! : Colors.transparent,
          ),
        ),
        padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_selectedImages.isNotEmpty)
              Container(
                height: 70,
                padding: const EdgeInsets.only(bottom: 8, top: 8),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedImages.length,
                  itemBuilder: (c, i) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            base64Decode(_selectedImages[i]),
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _selectedImages.removeAt(i)),
                            child: CircleAvatar(
                              radius: 10,
                              backgroundColor: Colors.black54,
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            TextField(
              controller: _controller,
              enabled: !isGenerating,
              textCapitalization: TextCapitalization.sentences,
              keyboardType: TextInputType.multiline,
              maxLines: 8,
              minLines: 1,
              style: theme.textTheme.bodyLarge,
              decoration: InputDecoration(
                hintText: 'Message Pocket LLM...',
                hintStyle: TextStyle(
                  color: theme.hintColor.withValues(alpha: 0.7),
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: isGenerating ? null : _pickImage,
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark ? Colors.grey[800] : Colors.grey[300],
                    ),
                    child: Icon(
                      Icons.add,
                      size: 20,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  tooltip: 'Add Image',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: isGenerating
                        ? Colors.grey
                        : theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: isGenerating ? null : _send,
                    icon: isGenerating
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : const Icon(
                            Icons.arrow_upward,
                            color: Colors.white,
                            size: 20,
                          ),
                    tooltip: 'Send',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
