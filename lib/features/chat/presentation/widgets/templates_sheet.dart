import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers.dart';
import '../../domain/models/message_template.dart';

class TemplatesSheet extends ConsumerWidget {
  final Function(String) onSelect;
  final Function(MessageTemplate)? onEdit;
  final Function(MessageTemplate)? onDelete;
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

        return ListView.builder(
          shrinkWrap: !isFullScreen,
          itemCount: templates.length,
          itemBuilder: (context, index) {
            final template = templates[index];
            return ListTile(
              title: Text(template.title),
              subtitle: Text(
                template.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => onSelect(template.content),
              trailing: (onEdit != null && onDelete != null)
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => onEdit!(template),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => onDelete!(template),
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
