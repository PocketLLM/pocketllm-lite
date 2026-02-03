import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
              title: Text(template['title'] ?? 'Untitled'),
              subtitle: Text(
                template['content'] ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => onSelect(template['content'] ?? ''),
            );
          },
        );
      },
    );
  }
}
