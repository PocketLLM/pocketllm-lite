import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../../../core/providers.dart';
import '../../../../services/backup_migration_service.dart';
import '../../../../services/local_memory_service.dart';
import '../../../../services/rag_service.dart';

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
  final _passwordController = TextEditingController();
  BackupArchivePayload? _encryptedPayload;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pllm', 'json'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() => _isLoading = true);

        final file = File(result.files.single.path!);
        final content = await file.readAsString();
        final envelope = jsonDecode(content) as Map<String, dynamic>;
        final isEncrypted = envelope['format'] == 'pocketllm-backup';
        if (isEncrypted && _passwordController.text.length < 8) {
          throw const BackupDecryptError(
            'Enter the backup password before selecting the .pllm file.',
          );
        }
        final payload = isEncrypted
            ? await BackupMigrationService().decryptBackup(
                encryptedJson: content,
                password: _passwordController.text,
              )
            : null;
        final data = payload == null
            ? envelope
            : <String, dynamic>{
                'version': 2,
                'chats': payload.chats,
                'prompts': payload.prompts,
                'settings': payload.settings,
                'personas': payload.personas,
                'memories': payload.memories,
                'skills': payload.skills,
              };

        // Simple validation
        if (data['chats'] == null &&
            data['prompts'] == null &&
            data['settings'] == null) {
          throw Exception('Invalid backup format');
        }

        setState(() {
          _previewData = data;
          _encryptedPayload = payload;
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
      late final Map<String, int> result;
      final payload = _encryptedPayload;
      if (payload == null) {
        result = await storage.importData(_previewData!);
      } else {
        result = await storage.restoreBackupDataAtomically(
          {
            'chats': payload.chats,
            'prompts': payload.prompts,
            'settings': payload.settings,
            'personas': payload.personas,
            'memories': payload.memories,
            'skills': payload.skills,
          },
          afterStorageWrite: () => ref
              .read(vectorStoreServiceProvider)
              .restoreArchiveAtomically(payload.documentIndex),
        );
        await LocalMemoryService().init(storage);
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Imported ${result['chats'] ?? 0} chats, ${result['prompts'] ?? 0} prompts, ${result['settings'] ?? 0} settings, ${result['personas'] ?? 0} personas, ${result['skills'] ?? 0} skills, and ${result['memories'] ?? 0} memories.',
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
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
              'Restore an encrypted .pllm backup, or import a legacy plaintext JSON export.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Text(
              'Note: Existing items with the same ID will be overwritten.',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Backup password for .pllm files',
              ),
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
                    child: CircularProgressIndicator(strokeWidth: 2),
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
                    child: CircularProgressIndicator(strokeWidth: 2),
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
        Icon(
          icon,
          size: 16,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Text('$label: '),
        Text('$count', style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
