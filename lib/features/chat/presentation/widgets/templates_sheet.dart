import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers.dart';

class TemplatesSheet extends ConsumerWidget {
  final Function(String) onSelect;

  const TemplatesSheet({
    super.key,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(storageServiceProvider);
    final templatesData = storage.getMessageTemplates();
    final templates = templatesData.map((template) => template['content'] ?? '').where((content) => content.isNotEmpty).toList();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: 32,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Quick Templates',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () async {
                      final template = await _showAddTemplateDialog(context);
                      if (template != null && template.isNotEmpty) {
                        final newTemplate = {
                          'id': DateTime.now().millisecondsSinceEpoch.toString(),
                          'title': 'Template ${DateTime.now()}',
                          'content': template,
                        };
                        storage.saveMessageTemplate(newTemplate);
                      }
                    },
                  ),
                ],
              ),
            ),
            
            // Templates list
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: templates.length,
                itemBuilder: (context, index) {
                  final template = templates[index];
                  return ListTile(
                    title: Text(
                      template,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () {
                        // Find and delete the template
                        final templatesData = storage.getMessageTemplates();
                        final templateToDelete = templatesData.firstWhere(
                          (t) => t['content'] == template,
                          orElse: () => {},
                        );
                        if (templateToDelete.isNotEmpty) {
                          storage.deleteMessageTemplate(templateToDelete['id']!);
                        }
                      },
                    ),
                    onTap: () {
                      onSelect(template);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _showAddTemplateDialog(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Template'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Enter template text...',
            ),
            maxLines: 5,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  Navigator.pop(context, controller.text.trim());
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }
}