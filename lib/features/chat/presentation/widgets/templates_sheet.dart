import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers.dart';

class TemplatesSheet extends ConsumerWidget {
  final Function(String) onSelect;
  final Function(Map<String, String>)? onEdit;
  final Function(String)? onDelete;
  final bool isFullScreen;

  const TemplatesSheet({
    super.key,
    required this.onSelect,
    this.onEdit,
    this.onDelete,
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
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Text('No templates yet'),
            ),
          );
        }

        final isManagementMode = onEdit != null || onDelete != null;

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
              trailing: isManagementMode
                  ? PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      onSelected: (value) {
                        if (value == 'edit' && onEdit != null) {
                          onEdit!(template);
                        } else if (value == 'delete' && onDelete != null) {
                          final id = template['id'];
                          if (id != null && id.isNotEmpty) {
                            onDelete!(id);
                          }
                        }
                      },
                      itemBuilder: (context) => [
                        if (onEdit != null)
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit, size: 20),
                                SizedBox(width: 8),
                                Text('Edit'),
                              ],
                            ),
                          ),
                        if (onDelete != null)
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, color: Colors.red, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Delete',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                      ],
                    )
                  : null,
            );
          },
        );
      },
    );
  }
}
