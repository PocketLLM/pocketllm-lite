import 'package:flutter/material.dart';

class OfflineNotificationPopup extends StatelessWidget {
  const OfflineNotificationPopup({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      icon: Icon(
        Icons.wifi_off_rounded,
        color: theme.colorScheme.primary,
        size: 32,
      ),
      title: Text(
        'Local-first privacy',
        style: theme.textTheme.headlineSmall?.copyWith(
          color: theme.colorScheme.onSurface,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Local inference can run without a cloud account.',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Cactus runs supported models on-device. Ollama sends prompts to the endpoint you configure. Optional downloads, search, updates, and skill installs use the network only when enabled.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'To get started:',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
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
            Navigator.of(context).pop(true);
          },
        ),
        FilledButton(
          child: const Text('I Understand'),
          onPressed: () {
            Navigator.of(context).pop(false);
          },
        ),
      ],
    );
  }

  Widget _buildStep(BuildContext context, String number, String text) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
