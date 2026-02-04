import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers.dart';
import '../../../chat/domain/models/message_template.dart';
import '../../../chat/presentation/widgets/templates_sheet.dart';
import '../dialogs/template_editor_dialog.dart';

class TemplateManagementScreen extends ConsumerStatefulWidget {
  const TemplateManagementScreen({super.key});

  @override
  ConsumerState<TemplateManagementScreen> createState() =>
      _TemplateManagementScreenState();
}

class _TemplateManagementScreenState
    extends ConsumerState<TemplateManagementScreen> {
  Future<void> _showEditor([MessageTemplate? template]) async {
    final result = await showDialog<MessageTemplate>(
      context: context,
      builder: (context) => TemplateEditorDialog(template: template),
    );

    if (result != null) {
      final storage = ref.read(storageServiceProvider);
      await storage.saveMessageTemplate(result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              template == null ? 'Template created' : 'Template updated',
            ),
          ),
        );
      }
    }
  }

  Future<void> _deleteTemplate(MessageTemplate template) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Template?'),
        content: Text('Delete "${template.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final storage = ref.read(storageServiceProvider);
      await storage.deleteMessageTemplate(template.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Template deleted')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
      body: TemplatesSheet(
        isFullScreen: true,
        onSelect: (content) {
          Clipboard.setData(ClipboardData(text: content));
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
        },
        onEdit: _showEditor,
        onDelete: _deleteTemplate,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditor(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
