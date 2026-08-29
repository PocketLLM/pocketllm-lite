import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/domain/background_task.dart';
import '../../../../core/providers.dart';
import '../../../../core/widgets/m3_app_bar.dart';
import '../../../../core/widgets/m3_section_header.dart';
import '../../../../core/widgets/model_prerequisite_dialog.dart';
import '../../../../services/audio_recording_service.dart';
import '../../../../services/audio_transcription_service.dart';

const _languages = <String, String>{
  'auto': 'Auto Detect',
  'en': 'English',
  'es': 'Spanish',
  'zh': 'Chinese',
  'ja': 'Japanese',
  'ko': 'Korean',
  'hi': 'Hindi',
  'de': 'German',
  'fr': 'French',
};

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
  bool? _modelInstalled;
  String? _error;
  late String _language;

  @override
  void initState() {
    super.initState();
    final saved = ref.read(storageServiceProvider).getSetting(
          AppConstants.audioLanguageKey,
          defaultValue: 'auto',
        );
    _language = _languages.containsKey(saved) ? saved as String : 'auto';
    Future.microtask(_refreshModelStatus);
  }

  Future<void> _refreshModelStatus() async {
    final installed =
        await ref.read(audioTranscriptionServiceProvider).isModelInstalled();
    if (mounted) setState(() => _modelInstalled = installed);
  }

  Future<void> _pickAudio() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['wav', 'mp3', 'm4a', 'aac', 'flac'],
    );
    final selected = picked?.files.single;
    if (selected?.path == null) return;
    try {
      await ref.read(audioRecordingServiceProvider).useFile(selected!.path!);
      if (mounted) setState(() => _error = null);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _transcribe(String filePath) async {
    if (_modelInstalled != true) {
      await _setupSpeechModel(resumeFilePath: filePath);
      return;
    }
    setState(() {
      _isProcessing = true;
      _error = null;
    });
    try {
      final result =
          await ref.read(audioTranscriptionServiceProvider).transcribeAudioFile(
                filePath: filePath,
                fileName: path.basename(filePath),
                language: _language,
              );
      if (mounted) setState(() => _currentResult = result);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _setupSpeechModel({String? resumeFilePath}) async {
    final result = await showModelPrerequisiteDialog(
      context: context,
      modelId: CactusWhisperTranscriber.modelId,
      title: 'Set up local transcription',
      explanation:
          'PocketLLM needs Whisper Tiny to transcribe this audio on device. After the verified download, transcription resumes automatically.',
    );
    if (!mounted) return;
    if (result == ModelPrerequisiteResult.installed) {
      setState(() {
        _modelInstalled = true;
        _error = null;
      });
      if (resumeFilePath != null) await _transcribe(resumeFilePath);
    } else if (result == ModelPrerequisiteResult.chooseAnother) {
      await context.push('/settings/model-catalog?query=Speech');
      await _refreshModelStatus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final recording = ref.watch(audioRecordingServiceProvider);
    final taskService = ref.watch(backgroundTaskServiceProvider);
    return Scaffold(
      appBar: M3AppBar(
        title: 'Audio Workspace',
        subtitle: 'Record, upload, and transcribe on device',
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
      body: ValueListenableBuilder<AudioRecordingState>(
        valueListenable: recording.state,
        builder: (context, recordingState, _) => ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            _SpeechModelCard(
              installed: _modelInstalled,
              onRefresh: _refreshModelStatus,
              onSetup: _setupSpeechModel,
            ),
            const M3SectionHeader(title: 'Audio source', icon: Icons.mic),
            _SourceCard(
              state: recordingState,
              recording: recording,
              onUpload: _pickAudio,
              onTranscribe: _transcribe,
              isProcessing: _isProcessing,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: DropdownButtonFormField<String>(
                initialValue: _language,
                decoration: const InputDecoration(
                  labelText: 'Transcription language',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(28)),
                  ),
                ),
                items: _languages.entries
                    .map(
                      (entry) => DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                    )
                    .toList(growable: false),
                onChanged: _isProcessing
                    ? null
                    : (value) async {
                        if (value == null) return;
                        setState(() => _language = value);
                        await ref.read(storageServiceProvider).saveSetting(
                              AppConstants.audioLanguageKey,
                              value,
                            );
                      },
              ),
            ),
            if (_error != null) _AudioErrorCard(message: _error!),
            if (_currentResult != null)
              _TranscriptCard(result: _currentResult!),
            ValueListenableBuilder<List<BackgroundTask>>(
              valueListenable: taskService.tasks,
              builder: (context, tasks, _) {
                final transcriptionTasks = tasks
                    .where(
                      (task) => task.type == BackgroundTaskType.transcription,
                    )
                    .toList(growable: false);
                if (transcriptionTasks.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const M3SectionHeader(
                      title: 'Transcription jobs',
                      icon: Icons.history,
                    ),
                    ...transcriptionTasks.take(10).map(
                          (task) => _TranscriptionTaskCard(task: task),
                        ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SpeechModelCard extends StatelessWidget {
  final bool? installed;
  final VoidCallback onRefresh;
  final Future<void> Function() onSetup;

  const _SpeechModelCard({
    required this.installed,
    required this.onRefresh,
    required this.onSetup,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card.filled(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: ListTile(
        leading:
            Icon(Icons.record_voice_over, color: theme.colorScheme.primary),
        title: const Text('Whisper Tiny speech model'),
        subtitle: Text(
          installed == null
              ? 'Checking local model…'
              : installed!
                  ? 'Installed · transcription stays on device'
                  : 'Not installed · required for transcription',
        ),
        trailing: installed == false
            ? IconButton.filledTonal(
                onPressed: onSetup,
                icon: const Icon(Icons.download_outlined),
                tooltip: 'Download required model',
              )
            : IconButton(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh model status',
              ),
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  final AudioRecordingState state;
  final AudioRecordingService recording;
  final VoidCallback onUpload;
  final Future<void> Function(String path) onTranscribe;
  final bool isProcessing;

  const _SourceCard({
    required this.state,
    required this.recording,
    required this.onUpload,
    required this.onTranscribe,
    required this.isProcessing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = state.phase == AudioRecordingPhase.recording ||
        state.phase == AudioRecordingPhase.paused;
    return Card.outlined(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!active && state.filePath == null)
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: recording.start,
                    icon: const Icon(Icons.mic),
                    label: const Text('Record'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onUpload,
                    icon: const Icon(Icons.audio_file),
                    label: const Text('Upload'),
                  ),
                ],
              ),
            if (active) ...[
              Text(
                _duration(state.elapsed),
                textAlign: TextAlign.center,
                style: theme.textTheme.displaySmall?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: ((state.amplitudeDb + 60) / 60).clamp(0.02, 1.0),
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                children: [
                  IconButton.filledTonal(
                    onPressed: state.phase == AudioRecordingPhase.paused
                        ? recording.resume
                        : recording.pause,
                    icon: Icon(
                      state.phase == AudioRecordingPhase.paused
                          ? Icons.play_arrow
                          : Icons.pause,
                    ),
                    tooltip: state.phase == AudioRecordingPhase.paused
                        ? 'Resume'
                        : 'Pause',
                  ),
                  IconButton.filled(
                    onPressed: recording.stop,
                    icon: const Icon(Icons.stop),
                    tooltip: 'Stop and save',
                  ),
                  IconButton.filledTonal(
                    onPressed: recording.cancel,
                    icon: const Icon(Icons.close),
                    tooltip: 'Cancel and delete',
                  ),
                ],
              ),
            ],
            if (!active && state.filePath != null) ...[
              Text(
                path.basename(state.filePath!),
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: recording.togglePlayback,
                    icon:
                        Icon(state.isPlaying ? Icons.pause : Icons.play_arrow),
                    label: Text(state.isPlaying ? 'Pause' : 'Play'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _rename(context),
                    icon: const Icon(Icons.edit),
                    label: const Text('Rename'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onUpload,
                    icon: const Icon(Icons.swap_horiz),
                    label: const Text('Replace'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed:
                    isProcessing ? null : () => onTranscribe(state.filePath!),
                icon: isProcessing
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.subtitles),
                label: Text(isProcessing ? 'Transcribing…' : 'Transcribe'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _rename(BuildContext context) async {
    final controller = TextEditingController(
      text: path.basenameWithoutExtension(state.filePath!),
    );
    try {
      final name = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Rename recording'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Recording name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: const Text('Save'),
            ),
          ],
        ),
      );
      if (name != null) await recording.rename(name);
    } finally {
      controller.dispose();
    }
  }

  String _duration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _TranscriptCard extends StatelessWidget {
  final AudioTranscriptionResult result;
  const _TranscriptCard({required this.result});

  @override
  Widget build(BuildContext context) => Card.filled(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                result.fileName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Whole-text result · ${_languages[result.language] ?? result.language} · no fabricated timestamps',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              SelectableText(result.text),
            ],
          ),
        ),
      );
}

class _TranscriptionTaskCard extends StatelessWidget {
  final BackgroundTask task;
  const _TranscriptionTaskCard({required this.task});

  @override
  Widget build(BuildContext context) => Card.outlined(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: ListTile(
          leading: Icon(
            task.state == BackgroundTaskState.completed
                ? Icons.check_circle_outline
                : task.state == BackgroundTaskState.failed
                    ? Icons.error_outline
                    : Icons.graphic_eq,
          ),
          title: Text(task.title, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            task.failure == null
                ? task.phase
                : '${task.failure!.message} ${task.failure!.action}',
          ),
        ),
      );
}

class _AudioErrorCard extends StatelessWidget {
  final String message;
  const _AudioErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card.filled(
      color: colors.errorContainer,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(message, style: TextStyle(color: colors.onErrorContainer)),
      ),
    );
  }
}
