import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../services/storage_service.dart';

class TagEditorDialog extends StatefulWidget {
  final String chatId;
  final StorageService storage;

  const TagEditorDialog({
    super.key,
    required this.chatId,
    required this.storage,
  });

  @override
  State<TagEditorDialog> createState() => _TagEditorDialogState();
}

class _TagEditorDialogState extends State<TagEditorDialog> {
  final TextEditingController _tagController = TextEditingController();
  late List<String> _currentTags;
  late Set<String> _availableTags;

  @override
  void initState() {
    super.initState();
    _refreshTags();
  }

  void _refreshTags() {
    setState(() {
      _currentTags = widget.storage.getTagsForChat(widget.chatId);
      _availableTags = widget.storage.getAllTags();
      // Remove tags already assigned to this chat from suggestions
      _availableTags.removeAll(_currentTags);
    });
  }

  @override
  void dispose() {
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _addTag(String tag) async {
    final cleanTag = tag.trim();
    if (cleanTag.isNotEmpty && !_currentTags.contains(cleanTag)) {
      await widget.storage.addTagToChat(widget.chatId, cleanTag);
      _tagController.clear();
      _refreshTags();
      HapticFeedback.lightImpact();
    }
  }

  Future<void> _removeTag(String tag) async {
    await widget.storage.removeTagFromChat(widget.chatId, tag);
    _refreshTags();
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Manage Tags'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current Tags
            if (_currentTags.isNotEmpty) ...[
              const Text(
                'Current Tags:',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children:
                    _currentTags.map((tag) {
                      return InputChip(
                        label: Text(tag),
                        onDeleted: () => _removeTag(tag),
                        deleteIcon: const Icon(Icons.close, size: 16),
                      );
                    }).toList(),
              ),
              const SizedBox(height: 16),
            ],

            // Add New Tag
            TextField(
              controller: _tagController,
              decoration: InputDecoration(
                labelText: 'Add Tag',
                hintText: 'Enter tag name',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _addTag(_tagController.text),
                ),
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              onSubmitted: _addTag,
            ),

            // Suggestions
            if (_availableTags.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Suggestions:',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 100),
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children:
                        _availableTags.map((tag) {
                          return ActionChip(
                            label: Text(tag),
                            onPressed: () => _addTag(tag),
                            avatar: const Icon(Icons.add, size: 14),
                            padding: EdgeInsets.zero,
                            labelStyle: const TextStyle(fontSize: 12),
                          );
                        }).toList(),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
