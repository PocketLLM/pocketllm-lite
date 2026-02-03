import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../../../core/providers.dart';

class ImportDialog extends ConsumerStatefulWidget {
  const ImportDialog({super.key});

  @override
  ConsumerState<ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends ConsumerState<ImportDialog> {
  bool _isLoading = false;
  Map<String, dynamic>? _previewData;
  int _chatsCount = 0;
  int _promptsCount = 0;
  int _settingsCount = 0;

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() => _isLoading = true);

        final file = File(result.files.single.path!);
        final content = await file.readAsString();
        final data = jsonDecode(content) as Map<String, dynamic>;

        // Simple validation
        if (data['chats'] == null &&
            data['prompts'] == null &&
            data['settings'] == null) {
          throw Exception('Invalid backup format');
        }

        setState(() {
          _previewData = data;
          _chatsCount = (data['chats'] as List?)?.length ?? 0;
          _promptsCount = (data['prompts'] as List?)?.length ?? 0;
          _settingsCount = (data['settings'] as Map?)?.length ?? 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error reading file: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _handleImport() async {
    if (_previewData == null) return;

    setState(() => _isLoading = true);

    try {
      final storage = ref.read(storageServiceProvider);
      final result = await storage.importData(_previewData!);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Imported ${result['chats']} chats, ${result['prompts']} prompts, and ${result['settings']} settings.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Import Data'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_previewData == null) ...[
            const Text(
              'Restore your chats and prompts from a JSON backup file.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            const Text(
              'Note: Existing items with the same ID will be overwritten.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ] else ...[
            const Text(
              'Backup file found:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildStatRow(Icons.chat_bubble_outline, 'Chats', _chatsCount),
            const SizedBox(height: 4),
            _buildStatRow(Icons.edit_note, 'System Prompts', _promptsCount),
            const SizedBox(height: 4),
            _buildStatRow(Icons.settings, 'Settings', _settingsCount),
            const SizedBox(height: 16),
            Text(
              'Ready to import?',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        if (_previewData == null)
          FilledButton.icon(
            onPressed: _isLoading ? null : _pickFile,
            icon: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.folder_open, size: 18),
            label: const Text('Select File'),
          )
        else
          FilledButton.icon(
            onPressed: _isLoading ? null : _handleImport,
            icon: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check, size: 18),
            label: const Text('Import'),
          ),
      ],
    );
  }

  Widget _buildStatRow(IconData icon, String label, int count) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Text('$label: '),
        Text('$count', style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
