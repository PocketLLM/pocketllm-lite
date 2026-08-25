import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/providers.dart';
import '../../../../services/backup_migration_service.dart';
import '../../../../services/rag_service.dart';

enum ExportFormat { json, csv, markdown, pdf }

class ExportDialog extends ConsumerStatefulWidget {
  final Set<String>? selectedChatIds;

  const ExportDialog({super.key, this.selectedChatIds});

  @override
  ConsumerState<ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends ConsumerState<ExportDialog> {
  bool _includeChats = true;
  bool _includePrompts = true;
  bool _includeSettings = true;
  ExportFormat _selectedFormat = ExportFormat.json;
  bool _isLoading = false;
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (widget.selectedChatIds != null) {
      _includeChats = true;
      _includePrompts = false;
      _includeSettings = false;
    }
  }

  Future<void> _handleExport() async {
    setState(() => _isLoading = true);

    try {
      final storage = ref.read(storageServiceProvider);
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      File file;
      String subject;

      if (_selectedFormat == ExportFormat.json) {
        final password = _passwordController.text;
        if (password.length < 8 ||
            password != _confirmPasswordController.text) {
          throw const BackupDecryptError(
            'Passwords must match and contain at least 8 characters.',
          );
        }
        final data = storage.exportBackupData(
          chatIds: widget.selectedChatIds?.toList(),
        );
        if (!_includeChats) data['chats'] = <dynamic>[];
        if (!_includePrompts) data['prompts'] = <dynamic>[];
        if (!_includeSettings) data['settings'] = <String, dynamic>{};
        final documentIndex =
            await ref.read(vectorStoreServiceProvider).exportArchive();
        final encrypted = await BackupMigrationService().createEncryptedBackup(
          password: password,
          settings:
              Map<String, dynamic>.from(data['settings'] as Map? ?? const {}),
          chats: List<dynamic>.from(data['chats'] as List? ?? const []),
          memories: List<dynamic>.from(
            data['memories'] as List? ?? const [],
          ),
          personas: List<dynamic>.from(
            data['personas'] as List? ?? const [],
          ),
          prompts: List<dynamic>.from(data['prompts'] as List? ?? const []),
          skills: List<dynamic>.from(data['skills'] as List? ?? const []),
          documentIndex: documentIndex,
        );
        file = File('${directory.path}/pocketllm_backup_$timestamp.pllm');
        await file.writeAsString(encrypted, flush: true);
        subject = 'pocketllm_backup_$timestamp.pllm';
      } else if (_selectedFormat == ExportFormat.csv) {
        // CSV Export (Summary)
        final csvString = storage.exportToCsv(
          chatIds: widget.selectedChatIds?.toList(),
        );
        file = File('${directory.path}/pocketllm_chats_$timestamp.csv');
        await file.writeAsString(csvString);
        subject = 'pocketllm_chats_$timestamp.csv';
      } else if (_selectedFormat == ExportFormat.markdown) {
        // Markdown Export (Readable)
        final mdString = storage.exportToMarkdown(
          chatIds: widget.selectedChatIds?.toList(),
        );
        file = File('${directory.path}/pocketllm_chats_$timestamp.md');
        await file.writeAsString(mdString);
        subject = 'pocketllm_chats_$timestamp.md';
      } else {
        // PDF Export
        final pdfBytes = await storage.exportToPdf(
          chatIds: widget.selectedChatIds?.toList(),
        );
        file = File('${directory.path}/pocketllm_chats_$timestamp.pdf');
        await file.writeAsBytes(pdfBytes);
        subject = 'pocketllm_chats_$timestamp.pdf';
      }

      // Share file
      if (mounted) {
        final box = context.findRenderObject() as RenderBox?;

        // ignore: deprecated_member_use
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
      title: Text(
        widget.selectedChatIds != null ? 'Export Selected' : 'Export Data',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.selectedChatIds != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  'Exporting ${widget.selectedChatIds!.length} chats',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const Text('Format', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<ExportFormat>(
              initialValue: _selectedFormat,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              items: const [
                DropdownMenuItem(
                  value: ExportFormat.json,
                  child: Text('Encrypted backup (.pllm)'),
                ),
                DropdownMenuItem(
                  value: ExportFormat.csv,
                  child: Text('CSV (Excel/Sheets)'),
                ),
                DropdownMenuItem(
                  value: ExportFormat.markdown,
                  child: Text('Markdown (Readable)'),
                ),
                DropdownMenuItem(
                  value: ExportFormat.pdf,
                  child: Text('PDF (Document)'),
                ),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedFormat = val);
              },
            ),
            const SizedBox(height: 16),
            if (isJson) ...[
              const Text(
                'Content',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              CheckboxListTile(
                title: const Text('Export Chats'),
                subtitle: const Text('Includes all chat history and images'),
                value: _includeChats,
                onChanged: widget.selectedChatIds != null
                    ? null
                    : (val) {
                        if (val != null) setState(() => _includeChats = val);
                      },
                contentPadding: EdgeInsets.zero,
              ),
              if (widget.selectedChatIds == null) ...[
                CheckboxListTile(
                  title: const Text('Export Prompts'),
                  subtitle: const Text('Includes custom system prompts'),
                  value: _includePrompts,
                  onChanged: (val) {
                    if (val != null) setState(() => _includePrompts = val);
                  },
                  contentPadding: EdgeInsets.zero,
                ),
                CheckboxListTile(
                  title: const Text('Export Settings'),
                  subtitle: const Text('Includes theme and configuration'),
                  value: _includeSettings,
                  onChanged: (val) {
                    if (val != null) setState(() => _includeSettings = val);
                  },
                  contentPadding: EdgeInsets.zero,
                ),
              ],
              if (!_includeChats && !_includePrompts && !_includeSettings)
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
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Backup password',
                  helperText:
                      'At least 8 characters. This password cannot be recovered.',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm password',
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(
                    alpha: 0.3,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedFormat == ExportFormat.csv
                            ? 'Exports a summary of all chats (ID, Title, Model, Date) suitable for spreadsheets.'
                            : 'Exports full conversation logs formatted for reading or sharing.',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
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
          onPressed: (_isLoading ||
                  (isJson &&
                      !_includeChats &&
                      !_includePrompts &&
                      !_includeSettings))
              ? null
              : _handleExport,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Export'),
        ),
      ],
    );
  }
}
