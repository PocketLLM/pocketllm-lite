import 'package:flutter/material.dart';

class OfflineNotificationPopup extends StatelessWidget {
  const OfflineNotificationPopup({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.wifi_off, color: Colors.blue),
          SizedBox(width: 12),
          Text('Offline Only'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This app is designed to run completely offline.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'All AI processing happens locally on your device using Ollama. No data is sent to external servers.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            const Text(
              'To get started:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildStep(context, '1', 'Install Ollama on your device'),
            const SizedBox(height: 8),
            _buildStep(context, '2', 'Start the Ollama service'),
            const SizedBox(height: 8),
            _buildStep(context, '3', 'Pull a model (e.g., llama3)'),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('Setup Guide'),
          onPressed: () {
            // Return true to indicate we should go to docs
            Navigator.of(context).pop(true);
          },
        ),
        FilledButton(
          child: const Text('I Understand'),
          onPressed: () {
            // Return false (or just pop) to proceed to chat
            Navigator.of(context).pop(false);
          },
        ),
      ],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }

  Widget _buildStep(BuildContext context, String number, String text) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text),
        ),
      ],
    );
  }
}
