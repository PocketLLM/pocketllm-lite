import 'package:flutter/material.dart';

class EditMessageDialog extends StatefulWidget {
  final String initialContent;
  final Function(String) onSave;

  const EditMessageDialog({
    super.key,
    required this.initialContent,
    required this.onSave,
  });

  @override
  State<EditMessageDialog> createState() => _EditMessageDialogState();
}

class _EditMessageDialogState extends State<EditMessageDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialContent);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Message'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Editing this message will remove all subsequent messages and regenerate the response.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            maxLines: 5,
            minLines: 1,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Enter your message...',
            ),
            autofocus: true,
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
          onPressed: () {
            final text = _controller.text.trim();
            if (text.isNotEmpty) {
              widget.onSave(text);
              Navigator.pop(context);
            }
          },
          child: const Text('Save & Regenerate'),
        ),
      ],
    );
  }
}
