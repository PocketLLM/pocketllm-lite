import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../services/storage_service.dart';

class BulkTagDialog extends StatefulWidget {
  final List<String> chatIds;
  final StorageService storage;

  const BulkTagDialog({
    super.key,
    required this.chatIds,
    required this.storage,
  });

  @override
  State<BulkTagDialog> createState() => _BulkTagDialogState();
}

class _BulkTagDialogState extends State<BulkTagDialog> {
  final TextEditingController _tagController = TextEditingController();
  final Set<String> _tagsToAdd = {};
  late Set<String> _availableTags;

  @override
  void initState() {
    super.initState();
    _refreshTags();
  }

  void _refreshTags() {
    setState(() {
      _availableTags = widget.storage.getAllTags();
      // Remove tags already selected to avoid duplicates in suggestions
      _availableTags.removeAll(_tagsToAdd);
    });
  }

  @override
  void dispose() {
    _tagController.dispose();
    super.dispose();
  }

  void _addTagToSelection(String tag) {
    final cleanTag = tag.trim();
    if (cleanTag.isNotEmpty && !_tagsToAdd.contains(cleanTag)) {
      setState(() {
        _tagsToAdd.add(cleanTag);
        _availableTags.remove(cleanTag);
      });
      _tagController.clear();
      HapticFeedback.lightImpact();
    }
  }

  void _removeTagFromSelection(String tag) {
    setState(() {
      _tagsToAdd.remove(tag);
      // Add back to available if it exists in storage
      if (widget.storage.getAllTags().contains(tag)) {
        _availableTags.add(tag);
      }
    });
    HapticFeedback.lightImpact();
  }

  Future<void> _applyTags() async {
    if (_tagsToAdd.isNotEmpty) {
      await widget.storage.bulkAddTagsToChats(widget.chatIds, _tagsToAdd.toList());
      HapticFeedback.mediumImpact();
    }
    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text('Add Tags to ${widget.chatIds.length} Chats'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tags to Add
            if (_tagsToAdd.isNotEmpty) ...[
              Text(
                'Tags to Add:',
                style: TextStyle(fontSize: 12, color: theme.colorScheme.primary),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _tagsToAdd.map((tag) {
                  return InputChip(
                    label: Text(tag),
                    onDeleted: () => _removeTagFromSelection(tag),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    backgroundColor: theme.colorScheme.primaryContainer,
                    labelStyle: TextStyle(color: theme.colorScheme.onPrimaryContainer),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],

            // Add New Tag Input
            TextField(
              controller: _tagController,
              decoration: InputDecoration(
                labelText: 'Enter Tag',
                hintText: 'Type tag name',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _addTagToSelection(_tagController.text),
                ),
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              onSubmitted: _addTagToSelection,
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
                    children: _availableTags.map((tag) {
                      return ActionChip(
                        label: Text(tag),
                        onPressed: () => _addTagToSelection(tag),
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
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _tagsToAdd.isEmpty ? null : _applyTags,
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
