import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../services/storage_service.dart';

class BulkTagDialog extends StatefulWidget {
  final List<String> selectedChatIds;
  final StorageService storage;

  const BulkTagDialog({
    super.key,
    required this.selectedChatIds,
    required this.storage,
  });

  @override
  State<BulkTagDialog> createState() => _BulkTagDialogState();
}

class _BulkTagDialogState extends State<BulkTagDialog> {
  final TextEditingController _tagController = TextEditingController();
  late Set<String> _availableTags;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _refreshTags();
  }

  void _refreshTags() {
    setState(() {
      _availableTags = widget.storage.getAllTags();
    });
  }

  @override
  void dispose() {
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _addTag(String tag) async {
    final cleanTag = tag.trim();
    if (cleanTag.isEmpty) return;

    setState(() => _isSaving = true);

    try {
      await widget.storage.bulkAddTagToChats(widget.selectedChatIds, cleanTag);
      HapticFeedback.mediumImpact();
      if (mounted) {
        Navigator.pop(context, true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Tag ${widget.selectedChatIds.length} Chats'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add a tag to all selected chats:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),

            // Input
            TextField(
              controller: _tagController,
              decoration: InputDecoration(
                labelText: 'Tag Name',
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
              enabled: !_isSaving,
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
                    children: _availableTags.map((tag) {
                      return ActionChip(
                        label: Text(tag),
                        onPressed: _isSaving ? null : () => _addTag(tag),
                        avatar: const Icon(Icons.add, size: 14),
                        padding: EdgeInsets.zero,
                        labelStyle: const TextStyle(fontSize: 12),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],

            if (_isSaving)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
