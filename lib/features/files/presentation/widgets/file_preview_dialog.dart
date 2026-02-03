import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/models/file_item.dart';

class FilePreviewDialog extends StatelessWidget {
  final FileItem fileItem;

  const FilePreviewDialog({super.key, required this.fileItem});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Icon(
                    Icons.description_outlined,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileItem.attachment.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'From: ${fileItem.chatTitle}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Content
          Flexible(
            child: Container(
              width: double.infinity,
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.3,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  fileItem.attachment.content,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          // Actions
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(text: fileItem.attachment.content),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Content copied to clipboard'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copy'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: const Text('Go to Chat'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
