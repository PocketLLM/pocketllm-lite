import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/providers.dart';

class TemplateManagementScreen extends ConsumerStatefulWidget {
  const TemplateManagementScreen({super.key});

  @override
  ConsumerState<TemplateManagementScreen> createState() =>
      _TemplateManagementScreenState();
}

class _TemplateManagementScreenState
    extends ConsumerState<TemplateManagementScreen> {
  void _showTemplateDialog({Map<String, String>? template}) {
    final isEditing = template != null;
    final titleController = TextEditingController(text: template?['title']);
    final contentController = TextEditingController(text: template?['content']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? 'Edit Template' : 'New Template'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Title (e.g., "Professional Sign-off")',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: contentController,
              decoration: const InputDecoration(
                labelText: 'Content',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final title = titleController.text.trim();
              final content = contentController.text.trim();

              if (title.isEmpty || content.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Title and content are required'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              final storage = ref.read(storageServiceProvider);
              final newTemplate = {
                'id': template?['id'] ?? const Uuid().v4(),
                'title': title,
                'content': content,
              };

              await storage.saveMessageTemplate(newTemplate);
              if (!mounted) return;

              navigator.pop();
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    isEditing ? 'Template updated' : 'Template created',
                  ),
                ),
              );
              setState(() {}); // Refresh list
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(String id, String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Template?'),
        content: Text('Are you sure you want to delete "$title"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              final storage = ref.read(storageServiceProvider);
              await storage.deleteMessageTemplate(id);
              if (!mounted) return;

              navigator.pop();
              messenger.showSnackBar(
                const SnackBar(content: Text('Template deleted')),
              );
              setState(() {}); // Refresh list
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final storage = ref.watch(storageServiceProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Message Templates'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (GoRouter.of(context).canPop()) {
              context.pop();
            } else {
              context.go('/settings');
            }
          },
        ),
      ),
      body: ValueListenableBuilder(
        valueListenable: storage.settingsBoxListenable,
        builder: (context, box, _) {
          final templates = storage.getMessageTemplates();

          if (templates.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.bolt,
                      size: 64,
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No templates yet',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create templates for quick replies like "Thanks!", "Please review", or common code snippets.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => _showTemplateDialog(),
                      icon: const Icon(Icons.add),
                      label: const Text('Create Template'),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: templates.length,
            itemBuilder: (context, index) {
              final template = templates[index];
              return ListTile(
                title: Text(
                  template['title'] ?? 'Untitled',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  template['content'] ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                leading: CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Icon(
                    Icons.text_snippet_outlined,
                    size: 20,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      tooltip: 'Edit',
                      onPressed: () => _showTemplateDialog(template: template),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: theme.colorScheme.error,
                      ),
                      tooltip: 'Delete',
                      onPressed: () => _confirmDelete(
                        template['id'] ?? '',
                        template['title'] ?? 'Untitled',
                      ),
                    ),
                  ],
                ),
                onTap: () {
                  HapticFeedback.selectionClick();
                  _showTemplateDialog(template: template);
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showTemplateDialog(),
        tooltip: 'Create Template',
        child: const Icon(Icons.add),
      ),
    );
  }
}
