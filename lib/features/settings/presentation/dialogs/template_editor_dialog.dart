import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../../features/chat/domain/models/message_template.dart';

class TemplateEditorDialog extends StatefulWidget {
  final MessageTemplate? template;

  const TemplateEditorDialog({super.key, this.template});

  @override
  State<TemplateEditorDialog> createState() => _TemplateEditorDialogState();
}

class _TemplateEditorDialogState extends State<TemplateEditorDialog> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.template?.title ?? '',
    );
    _contentController = TextEditingController(
      text: widget.template?.content ?? '',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      final id = widget.template?.id ?? const Uuid().v4();
      final template = MessageTemplate(
        id: id,
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
      );
      Navigator.pop(context, template);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.template != null;
    return AlertDialog(
      title: Text(isEditing ? 'Edit Template' : 'New Template'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                  hintText: 'e.g., Code Block, Signature',
                ),
                textCapitalization: TextCapitalization.sentences,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _contentController,
                decoration: const InputDecoration(
                  labelText: 'Content',
                  border: OutlineInputBorder(),
                  hintText: 'The text to insert...',
                  alignLabelWithHint: true,
                ),
                maxLines: 5,
                minLines: 3,
                textCapitalization: TextCapitalization.sentences,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter content';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
