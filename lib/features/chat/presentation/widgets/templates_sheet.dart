import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers.dart';

class TemplatesSheet extends ConsumerWidget {
  final Function(String) onSelect;
  final bool isFullScreen;

  const TemplatesSheet({
    super.key,
    required this.onSelect,
    this.isFullScreen = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(storageServiceProvider);

    return ValueListenableBuilder(
      valueListenable: storage.settingsBoxListenable,
      builder: (context, box, _) {
        final templates = storage.getMessageTemplates();

        if (templates.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bolt, size: 48, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No templates yet'),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      context.push('/settings/templates');
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Create Template'),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Select Template',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      context.push('/settings/templates');
                    },
                    child: const Text('Manage'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: !isFullScreen,
                itemCount: templates.length,
                itemBuilder: (context, index) {
                  final template = templates[index];
                  return ListTile(
                    title: Text(template['title'] ?? 'Untitled'),
                    subtitle: Text(
                      template['content'] ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    leading: const Icon(Icons.text_snippet_outlined),
                    onTap: () => onSelect(template['content'] ?? ''),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
