import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/providers.dart';

class ExportDialog extends ConsumerStatefulWidget {
  const ExportDialog({super.key});

  @override
  ConsumerState<ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends ConsumerState<ExportDialog> {
  bool _includeChats = true;
  bool _includePrompts = true;
  bool _isLoading = false;

  Future<void> _handleExport() async {
    setState(() => _isLoading = true);

    try {
      final storage = ref.read(storageServiceProvider);

      // Get data from storage
      final data = storage.exportData(
        includeChats: _includeChats,
        includePrompts: _includePrompts,
      );

      // Convert to JSON
      final jsonString = const JsonEncoder.withIndent('  ').convert(data);

      // Save to temp file
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${directory.path}/pocketllm_export_$timestamp.json');
      await file.writeAsString(jsonString);

      // Share file
      if (mounted) {
        final box = context.findRenderObject() as RenderBox?;

        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'PocketLLM Lite Export',
          subject: 'pocketllm_export_$timestamp.json',
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
    return AlertDialog(
      title: const Text('Export Data'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CheckboxListTile(
            title: const Text('Export Chats'),
            subtitle: const Text('Includes all chat history and images'),
            value: _includeChats,
            onChanged: (val) {
              if (val != null) setState(() => _includeChats = val);
            },
          ),
          CheckboxListTile(
            title: const Text('Export Prompts'),
            subtitle: const Text('Includes custom system prompts'),
            value: _includePrompts,
            onChanged: (val) {
              if (val != null) setState(() => _includePrompts = val);
            },
          ),
          if (!_includeChats && !_includePrompts)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'Please select at least one item to export.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: (_isLoading || (!_includeChats && !_includePrompts))
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
