import 'package:flutter/material.dart';

class OfflineNotificationPopup extends StatelessWidget {
  const OfflineNotificationPopup({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Offline Only'),
      content: const SingleChildScrollView(
        child: ListBody(
          children: <Widget>[
            Text(
              'This app only runs offline.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text(
              'All AI processing happens locally on your device using Ollama. '
              'No data is sent to any external servers.',
            ),
            SizedBox(height: 16),
            Text(
              'To use the app, you need to:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('1. Install Ollama on your device'),
            Text('2. Start the Ollama service'),
            Text('3. Pull a model (e.g., llama3)'),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('OK'),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}