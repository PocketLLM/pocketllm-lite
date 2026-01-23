import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../services/storage_service.dart';

class BulkTagDialog extends StatefulWidget {
  final StorageService storage;

  const BulkTagDialog({
    super.key,
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
    _availableTags = widget.storage.getAllTags();
  }

  @override
  void dispose() {
    _tagController.dispose();
    super.dispose();
  }

  void _addNewTag(String tag) {
    final cleanTag = tag.trim();
    if (cleanTag.isNotEmpty) {
      setState(() {
        _selectedTags.add(cleanTag);
        _tagController.clear();
      });
      HapticFeedback.lightImpact();
    }
  }

  void _toggleTag(String tag) {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        _selectedTags.add(tag);
      }
    });
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Tags to Selected'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Selected Tags Preview
            if (_selectedTags.isNotEmpty) ...[
              const Text(
                'Tags to Add:',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children:
                    _selectedTags.map((tag) {
                      return Chip(
                        label: Text(tag),
                        onDeleted: () => _toggleTag(tag),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        backgroundColor:
                            Theme.of(context).colorScheme.primaryContainer,
                        labelStyle: TextStyle(
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      );
                    }).toList(),
              ),
              const SizedBox(height: 16),
            ],

            // Add New Tag Field
            TextField(
              controller: _tagController,
              decoration: InputDecoration(
                labelText: 'New Tag',
                hintText: 'Enter tag name',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _addNewTag(_tagController.text),
                ),
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              onSubmitted: _addNewTag,
            ),

            // Available Tags
            if (_availableTags.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Available Tags:',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 150),
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children:
                        _availableTags.map((tag) {
                          final isSelected = _selectedTags.contains(tag);
                          // Don't show if already selected (shown in top section)
                          if (isSelected) return const SizedBox.shrink();

                          return ActionChip(
                            label: Text(tag),
                            onPressed: () => _toggleTag(tag),
                            avatar: const Icon(Icons.add, size: 14),
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
          onPressed: () => Navigator.pop(context, _selectedTags.toList()),
          child: const Text('Add Tags'),
        ),
      ],
    );
  }
}
