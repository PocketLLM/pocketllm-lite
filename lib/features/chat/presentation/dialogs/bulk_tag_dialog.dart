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
  final Set<String> _selectedTags = {};
  late Set<String> _availableTags;

  @override
  void initState() {
    super.initState();
    _refreshTags();
  }

  void _refreshTags() {
    setState(() {
      _availableTags = widget.storage.getAllTags();
      // Don't remove selected tags from suggestions, or maybe do?
      // If we select a tag, it moves to "Tags to Add".
      _availableTags.removeAll(_selectedTags);
    });
  }

  @override
  void dispose() {
    _tagController.dispose();
    super.dispose();
  }

  void _selectTag(String tag) {
    final cleanTag = tag.trim();
    if (cleanTag.isNotEmpty && !_selectedTags.contains(cleanTag)) {
      setState(() {
        _selectedTags.add(cleanTag);
      });
      _tagController.clear();
      _refreshTags();
      HapticFeedback.lightImpact();
    }
  }

  void _deselectTag(String tag) {
    setState(() {
      _selectedTags.remove(tag);
    });
    _refreshTags();
    HapticFeedback.lightImpact();
  }

  Future<void> _applyTags() async {
    if (_selectedTags.isNotEmpty) {
      await widget.storage.bulkAddTagsToChats(widget.chatIds, _selectedTags.toList());
      HapticFeedback.mediumImpact();
    }
    if (mounted) {
      Navigator.pop(context, _selectedTags.isNotEmpty);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text('Tag ${widget.chatIds.length} Chats'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tags to Add:',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(minHeight: 40),
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: _selectedTags.isEmpty
                  ? Center(
                      child: Text(
                        'No tags selected',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    )
                  : Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: _selectedTags.map((tag) {
                        return InputChip(
                          label: Text(tag),
                          onDeleted: () => _deselectTag(tag),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          backgroundColor: theme.colorScheme.primaryContainer,
                          labelStyle: TextStyle(
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        );
                      }).toList(),
                    ),
            ),

            const SizedBox(height: 16),

            // Add New Tag
            TextField(
              controller: _tagController,
              decoration: InputDecoration(
                labelText: 'Create or Select Tag',
                hintText: 'Enter tag name',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _selectTag(_tagController.text),
                ),
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              onSubmitted: _selectTag,
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
                        onPressed: () => _selectTag(tag),
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
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _selectedTags.isEmpty ? null : _applyTags,
          child: const Text('Apply Tags'),
        ),
      ],
    );
  }
}
