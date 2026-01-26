import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../services/storage_service.dart';

class BulkTagDialog extends StatefulWidget {
  final int selectedCount;
  final StorageService storage;

  const BulkTagDialog({
    super.key,
    required this.selectedCount,
    required this.storage,
  });

  @override
  State<BulkTagDialog> createState() => _BulkTagDialogState();
}

class _BulkTagDialogState extends State<BulkTagDialog> {
  final TextEditingController _tagController = TextEditingController();
  late Set<String> _availableTags;

  @override
  void initState() {
    super.initState();
    _availableTags = widget.storage.getAllTags();
  }

  @override
  void dispose() {
    _tagController.dispose();
    super.dispose();
  }

  void _submit(String tag) {
    final cleanTag = tag.trim();
    if (cleanTag.isNotEmpty) {
      Navigator.pop(context, cleanTag);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Tag ${widget.selectedCount} Chats'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add a tag to selected chats:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _tagController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Tag Name',
                hintText: 'Enter tag name',
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              onSubmitted: _submit,
            ),

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
                        onPressed: () {
                           HapticFeedback.selectionClick();
                           _submit(tag);
                        },
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
          onPressed: () => _submit(_tagController.text),
          child: const Text('Add Tag'),
        ),
      ],
    );
  }
}
