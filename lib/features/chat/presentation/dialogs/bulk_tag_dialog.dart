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
  late Set<String> _availableTags;
  bool _isLoading = false;

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

    setState(() => _isLoading = true);

    try {
      await widget.storage.addTagToChats(widget.chatIds, cleanTag);
      HapticFeedback.mediumImpact();
      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add tag: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Tag ${widget.chatIds.length} Chats'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add a tag to all selected chats:',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _tagController,
              autofocus: true,
              enabled: !_isLoading,
              decoration: InputDecoration(
                labelText: 'Tag Name',
                hintText: 'e.g. Work, Ideas',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _isLoading ? null : () => _addTag(_tagController.text),
                ),
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              onSubmitted: _isLoading ? null : _addTag,
            ),
            if (_availableTags.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Existing Tags:',
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
                        onPressed: _isLoading ? null : () => _addTag(tag),
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
          onPressed: _isLoading ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
      ],
    );
  }
}
