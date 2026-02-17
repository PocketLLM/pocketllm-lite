import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/providers.dart';
import '../../../../core/widgets/m3_app_bar.dart';
import '../../../../services/storage_service.dart';
import '../../../chat/domain/models/system_prompt.dart';

class SystemPromptDetailsScreen extends ConsumerStatefulWidget {
  final String? promptId;

  const SystemPromptDetailsScreen({super.key, this.promptId});

  @override
  ConsumerState<SystemPromptDetailsScreen> createState() =>
      _SystemPromptDetailsScreenState();
}

class _SystemPromptDetailsScreenState
    extends ConsumerState<SystemPromptDetailsScreen> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  final _formKey = GlobalKey<FormState>();
  bool _isEditing = false;
  SystemPrompt? _existingPrompt;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _contentController = TextEditingController();
    _loadPrompt();
  }

  void _loadPrompt() {
    if (widget.promptId == null || widget.promptId == 'new') {
      _isEditing = true;
      return;
    }

    final storage = ref.read(storageServiceProvider);
    final prompts = storage.getSystemPrompts();
    try {
      _existingPrompt = prompts.firstWhere((p) => p.id == widget.promptId);
      _titleController.text = _existingPrompt!.title;
      _contentController.text = _existingPrompt!.content;
    } catch (e) {
      // Prompt not found, handle error or treat as new
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _savePrompt() async {
    if (!_formKey.currentState!.validate()) return;

    HapticFeedback.mediumImpact();

    final storage = ref.read(storageServiceProvider);
    final newPrompt = SystemPrompt(
      id: _existingPrompt?.id ?? const Uuid().v4(),
      title: _titleController.text.trim(),
      content: _contentController.text.trim(),
    );

    await storage.saveSystemPrompt(newPrompt);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _existingPrompt == null ? 'Prompt created' : 'Prompt updated',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.pop();
    }
  }

  Future<void> _deletePrompt() async {
    if (_existingPrompt == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Prompt?'),
        content: Text(
          'Are you sure you want to delete "${_existingPrompt!.title}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final storage = ref.read(storageServiceProvider);
      await storage.deleteSystemPrompt(_existingPrompt!.id);
      if (mounted) {
        context.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNew = _existingPrompt == null;

    return Scaffold(
      appBar: M3AppBar(
        title: isNew ? 'New System Prompt' : 'Edit Prompt',
        onBack: () => context.pop(),
        actions: [
          if (!isNew)
            IconButton(
              icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
              tooltip: 'Delete Prompt',
              onPressed: _deletePrompt,
            ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _savePrompt,
        icon: const Icon(Icons.save),
        label: const Text('Save'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Prompt Details',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Title',
                hintText: 'e.g., Python Expert, Creative Writer',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.title),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a title';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            Text(
              'Instructions',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Define the persona and rules for the AI model.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _contentController,
              decoration: InputDecoration(
                hintText: 'You are a helpful assistant who...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                alignLabelWithHint: true,
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
              ),
              maxLines: 15,
              minLines: 8,
              textAlignVertical: TextAlignVertical.top,
              textCapitalization: TextCapitalization.sentences,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter the prompt content';
                }
                return null;
              },
            ),
            const SizedBox(height: 80), // Space for FAB
          ],
        ),
      ),
    );
  }
}
