import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers.dart';
import '../../../../services/storage_service.dart';

class TemplatesSheet extends ConsumerStatefulWidget {
  final Function(String content) onSelect;
  final bool isFullScreen;

  const TemplatesSheet({
    super.key,
    required this.onSelect,
    this.isFullScreen = false,
  });

  @override
  ConsumerState<TemplatesSheet> createState() => _TemplatesSheetState();
}

class _TemplatesSheetState extends ConsumerState<TemplatesSheet> {
  List<Map<String, String>> _templates = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    final storage = ref.read(storageServiceProvider);
    // Add small delay to allow UI to settle if triggered immediately
    await Future.delayed(Duration.zero);
    if (!mounted) return;

    setState(() {
      _templates = storage.getMessageTemplates();
      _isLoading = false;
    });
  }

  void _showEditDialog([Map<String, String>? template]) {
    final titleCtrl = TextEditingController(text: template?['title'] ?? '');
    final contentCtrl = TextEditingController(text: template?['content'] ?? '');
    final isEditing = template != null;

    showDialog(
      context: context,
      builder: (context) {
        String? titleError;
        String? contentError;

        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text(isEditing ? 'Edit Template' : 'New Template'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: InputDecoration(
                    labelText: 'Label (e.g., Fix Grammar)',
                    errorText: titleError,
                    border: const OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                  onChanged: (_) {
                    if (titleError != null) setState(() => titleError = null);
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: contentCtrl,
                  decoration: InputDecoration(
                    labelText: 'Message Content',
                    hintText: 'Fix grammar in the following text:',
                    errorText: contentError,
                    border: const OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) {
                    if (contentError != null) setState(() => contentError = null);
                  },
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
                  final title = titleCtrl.text.trim();
                  final content = contentCtrl.text.trim();

                  if (title.isEmpty || content.isEmpty) {
                    setState(() {
                      if (title.isEmpty) titleError = 'Required';
                      if (content.isEmpty) contentError = 'Required';
                    });
                    HapticFeedback.lightImpact();
                    return;
                  }

                  final newTemplate = {
                    'id': template?['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
                    'title': title,
                    'content': content,
                  };

                  final storage = ref.read(storageServiceProvider);
                  await storage.saveMessageTemplate(newTemplate);

                  if (mounted) {
                    Navigator.pop(context);
                    HapticFeedback.mediumImpact();
                    _loadTemplates();
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Template?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final storage = ref.read(storageServiceProvider);
              await storage.deleteMessageTemplate(id);
              if (mounted) {
                Navigator.pop(context);
                HapticFeedback.mediumImpact();
                _loadTemplates();
              }
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
    final theme = Theme.of(context);

    Widget content = Column(
      mainAxisSize: widget.isFullScreen ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (!widget.isFullScreen) ...[
          const SizedBox(height: 4),
          Container(
            width: 32,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Quick Templates',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _showEditDialog(),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Create'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
        ],

        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(32.0),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_templates.isEmpty)
           Padding(
              padding: const EdgeInsets.all(32.0),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutQuart,
                builder: (context, value, child) {
                  return Transform.translate(
                    offset: Offset(0, 20 * (1 - value)),
                    child: Opacity(
                      opacity: value,
                      child: child,
                    ),
                  );
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.bolt,
                      size: 48,
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No templates yet',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Save common prompts for quick access.',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (widget.isFullScreen) ...[
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: () => _showEditDialog(),
                        icon: const Icon(Icons.add),
                        label: const Text('Create New Template'),
                      ),
                    ]
                  ],
                ),
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: !widget.isFullScreen,
                itemCount: _templates.length,
                itemBuilder: (context, index) {
                  final template = _templates[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      radius: 18,
                      child: Icon(
                        Icons.bolt,
                        size: 18,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    title: Text(
                      template['title'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      template['content'] ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      widget.onSelect(template['content'] ?? '');
                    },
                    trailing: PopupMenuButton(
                      icon: const Icon(Icons.more_vert, size: 20),
                      onSelected: (value) {
                        if (value == 'edit') {
                          _showEditDialog(template);
                        } else if (value == 'delete') {
                          _confirmDelete(template['id']!);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 18),
                              SizedBox(width: 12),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 18, color: Colors.red),
                              SizedBox(width: 12),
                              Text('Delete', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
      ],
    );

    if (widget.isFullScreen) {
      return content;
    }

    return Container(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      child: content,
    );
  }
}
