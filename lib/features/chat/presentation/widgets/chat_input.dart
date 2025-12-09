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

    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_selectedImages.isNotEmpty)
            Container(
              height: 70,
              padding: const EdgeInsets.only(bottom: 8),
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
                          child: Container(
                            color: Colors.black54,
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.add_photo_alternate_outlined),
                onPressed: isGenerating ? null : _pickImage,
                color: theme.colorScheme.secondary,
              ),
              Expanded(
                child: TextField(
                  controller: _controller,
                  enabled: !isGenerating,
                  textCapitalization: TextCapitalization.sentences,
                  keyboardType: TextInputType.multiline,
                  maxLines: 5,
                  minLines: 1,
                  decoration: InputDecoration(
                    hintText: 'Message Pocket LLM...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: isGenerating
                    ? Colors.grey
                    : theme.colorScheme.primary,
                child: IconButton(
                  icon: isGenerating
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.send_rounded, color: Colors.white),
                  onPressed: isGenerating ? null : _send,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
