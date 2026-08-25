import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/m3_app_bar.dart';
import '../../../../core/widgets/m3_empty_state.dart';
import '../../../../services/audio_transcription_service.dart';

class AudioTranscriptionScreen extends ConsumerStatefulWidget {
  const AudioTranscriptionScreen({super.key});

  @override
  ConsumerState<AudioTranscriptionScreen> createState() =>
      _AudioTranscriptionScreenState();
}

class _AudioTranscriptionScreenState
    extends ConsumerState<AudioTranscriptionScreen> {
  AudioTranscriptionResult? _currentResult;
  bool _isProcessing = false;
  String? _error;

  Future<void> _pickAndTranscribe() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['wav', 'mp3', 'm4a', 'aac', 'flac'],
    );
    final selected = picked?.files.single;
    if (selected?.path == null) return;
    setState(() {
      _isProcessing = true;
      _error = null;
    });
    try {
      final result = await AudioTranscriptionService().transcribeAudioFile(
        filePath: selected!.path!,
        fileName: selected.name,
      );
      if (mounted) setState(() => _currentResult = result);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: M3AppBar(
        title: 'Audio Workspace',
        subtitle: 'On-device Whisper transcription',
        actions: [
          if (_currentResult != null)
            IconButton(
              tooltip: 'Copy transcript',
              icon: const Icon(Icons.copy_rounded),
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: _currentResult!.exportToMarkdown()),
                );
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Transcript copied')),
                );
              },
            ),
        ],
      ),
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator())
          : _currentResult == null
              ? M3EmptyState(
                  icon: Icons.graphic_eq_rounded,
                  title: _error == null
                      ? 'No audio selected'
                      : 'Transcription failed',
                  description: _error ??
                      'Choose an audio file. Transcription stays on device and '
                          'requires an already installed Whisper model; automatic '
                          'model downloads are disabled.',
                  action: FilledButton.icon(
                    icon: const Icon(Icons.audio_file_rounded),
                    label: Text(
                      _error == null ? 'Choose audio file' : 'Try another file',
                    ),
                    onPressed: _pickAndTranscribe,
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card.filled(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.audio_file_rounded,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _currentResult!.fileName,
                                    style: theme.textTheme.titleMedium,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SelectableText(_currentResult!.text),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _pickAndTranscribe,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Transcribe another file'),
                    ),
                  ],
                ),
    );
  }
}
