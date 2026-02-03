import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers.dart';

class TemplatesSheet extends ConsumerWidget {
  final Function(String) onSelect;
  final bool isFullScreen;
  final Function(String)? onDelete;

  const TemplatesSheet({
    super.key,
    required this.onSelect,
    this.isFullScreen = false,
    this.onDelete,
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
                  Icon(
                    Icons.bolt_outlined,
                    size: 48,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No templates yet',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (onDelete != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Tap + to create one',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          );
        }

        return ListView.builder(
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
              onTap: () => onSelect(template['content'] ?? ''),
              trailing: onDelete != null
                  ? IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Delete template',
                      onPressed: () {
                        final id = template['id'];
                        if (id != null) {
                          onDelete!(id);
                        }
                      },
                    )
                  : null,
            );
          },
        );
      },
    );
  }
}
