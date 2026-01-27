import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers.dart';
import '../../../chat/domain/models/pull_progress.dart';

class ModelDownloadDialog extends ConsumerStatefulWidget {
  const ModelDownloadDialog({super.key});

  @override
  ConsumerState<ModelDownloadDialog> createState() =>
      _ModelDownloadDialogState();
}

class _ModelDownloadDialogState extends ConsumerState<ModelDownloadDialog> {
  final _controller = TextEditingController();
  bool _isDownloading = false;
  String? _status;
  double _percentage = 0.0;
  String? _error;
  StreamSubscription<PullProgress>? _subscription;

  @override
  void dispose() {
    _controller.dispose();
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _startDownload() async {
    final modelName = _controller.text.trim();
    if (modelName.isEmpty) return;

    setState(() {
      _isDownloading = true;
      _error = null;
      _status = 'Starting...';
      _percentage = 0.0;
    });

    try {
      final ollamaService = ref.read(ollamaServiceProvider);
      final stream = ollamaService.pullModel(modelName);

      _subscription = stream.listen(
        (progress) {
          setState(() {
            _status = progress.status;
            _percentage = progress.percentage;
          });

          if (progress.status == 'success') {
            // Download complete
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Successfully downloaded $modelName'),
                  backgroundColor: Colors.green,
                ),
              );
              Navigator.of(
                context,
              ).pop(true); // Return true to indicate success
            }
          }
        },
        onError: (e) {
          setState(() {
            _isDownloading = false;
            _error = e.toString();
          });
        },
        cancelOnError: true,
      );
    } catch (e) {
      setState(() {
        _isDownloading = false;
        _error = e.toString();
      });
    }
  }

  void _cancelDownload() {
    _subscription?.cancel();
    setState(() {
      _isDownloading = false;
      _status = 'Cancelled';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Download Model'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_isDownloading) ...[
            const Text(
              'Enter the model tag to download from Ollama library.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: 'e.g. llama3, mistral, llava',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _startDownload(),
            ),
            const SizedBox(height: 8),
            Text(
              'Make sure you have enough disk space and a stable internet connection.',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ] else ...[
            Text(
              'Downloading ${_controller.text}...',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: _percentage > 0 ? _percentage : null,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _status ?? 'Initializing...',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${(_percentage * 100).toInt()}%',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                _error!,
                style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
              ),
            ),
        ],
      ),
      actions: [
        if (_isDownloading)
          TextButton(onPressed: _cancelDownload, child: const Text('Cancel'))
        else
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Close'),
          ),

        if (!_isDownloading)
          FilledButton(
            onPressed: _startDownload,
            child: const Text('Download'),
          ),
      ],
    );
  }
}
