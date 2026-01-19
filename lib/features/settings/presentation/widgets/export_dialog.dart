import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/providers.dart';

enum ExportFormat { json, csv, markdown }

class ExportDialog extends ConsumerStatefulWidget {
  const ExportDialog({super.key});

  @override
  ConsumerState<ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends ConsumerState<ExportDialog> {
  bool _includeChats = true;
  bool _includePrompts = true;
  ExportFormat _selectedFormat = ExportFormat.json;
  bool _isLoading = false;

  Future<void> _handleExport() async {
    setState(() => _isLoading = true);

    try {
      final storage = ref.read(storageServiceProvider);
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      File file;
      String subject;

      if (_selectedFormat == ExportFormat.json) {
        // JSON Export (Backup)
        final data = storage.exportData(
          includeChats: _includeChats,
          includePrompts: _includePrompts,
        );
        final jsonString = const JsonEncoder.withIndent('  ').convert(data);
        file = File('${directory.path}/pocketllm_backup_$timestamp.json');
        await file.writeAsString(jsonString);
        subject = 'pocketllm_backup_$timestamp.json';
      } else if (_selectedFormat == ExportFormat.csv) {
        // CSV Export (Summary)
        final csvString = storage.exportToCsv();
        file = File('${directory.path}/pocketllm_chats_$timestamp.csv');
        await file.writeAsString(csvString);
        subject = 'pocketllm_chats_$timestamp.csv';
      } else {
        // Markdown Export (Readable)
        final mdString = storage.exportToMarkdown();
        file = File('${directory.path}/pocketllm_chats_$timestamp.md');
        await file.writeAsString(mdString);
        subject = 'pocketllm_chats_$timestamp.md';
      }

      // Share file
      if (mounted) {
        final box = context.findRenderObject() as RenderBox?;

        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'PocketLLM Lite Export',
          subject: subject,
          sharePositionOrigin: box!.localToGlobal(Offset.zero) & box.size,
        );

        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isJson = _selectedFormat == ExportFormat.json;

    return AlertDialog(
      title: const Text('Export Data'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Format', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<ExportFormat>(
              value: _selectedFormat,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: const [
                DropdownMenuItem(
                  value: ExportFormat.json,
                  child: Text('JSON (Full Backup)'),
                ),
                DropdownMenuItem(
                  value: ExportFormat.csv,
                  child: Text('CSV (Excel/Sheets)'),
                ),
                DropdownMenuItem(
                  value: ExportFormat.markdown,
                  child: Text('Markdown (Readable)'),
                ),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedFormat = val);
              },
            ),
            const SizedBox(height: 16),

            if (isJson) ...[
              const Text('Content', style: TextStyle(fontWeight: FontWeight.bold)),
              CheckboxListTile(
                title: const Text('Export Chats'),
                subtitle: const Text('Includes all chat history and images'),
                value: _includeChats,
                onChanged: (val) {
                  if (val != null) setState(() => _includeChats = val);
                },
                contentPadding: EdgeInsets.zero,
              ),
              CheckboxListTile(
                title: const Text('Export Prompts'),
                subtitle: const Text('Includes custom system prompts'),
                value: _includePrompts,
                onChanged: (val) {
                  if (val != null) setState(() => _includePrompts = val);
                },
                contentPadding: EdgeInsets.zero,
              ),
              if (!_includeChats && !_includePrompts)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    'Please select at least one item to export.',
                    style: TextStyle(
                      color: theme.colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 20, color: theme.colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedFormat == ExportFormat.csv
                          ? 'Exports a summary of all chats (ID, Title, Model, Date) suitable for spreadsheets.'
                          : 'Exports full conversation logs formatted for reading or sharing.',
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: (_isLoading || (isJson && !_includeChats && !_includePrompts))
              ? null
              : _handleExport,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Export'),
        ),
      ],
    );
  }
}
