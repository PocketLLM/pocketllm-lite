import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/model_browser/domain/model_store_model.dart';
import '../../features/model_browser/providers/model_store_provider.dart';
import '../../providers/model_manager_provider.dart';
import '../../services/model_download_service.dart';
import '../providers.dart';

enum ModelPrerequisiteResult { installed, chooseAnother, skipped }

Future<ModelPrerequisiteResult?> showModelPrerequisiteDialog({
  required BuildContext context,
  required String modelId,
  required String title,
  required String explanation,
}) {
  return showDialog<ModelPrerequisiteResult>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ModelPrerequisiteDialog(
      modelId: modelId,
      title: title,
      explanation: explanation,
    ),
  );
}

class _ModelPrerequisiteDialog extends ConsumerStatefulWidget {
  final String modelId;
  final String title;
  final String explanation;

  const _ModelPrerequisiteDialog({
    required this.modelId,
    required this.title,
    required this.explanation,
  });

  @override
  ConsumerState<_ModelPrerequisiteDialog> createState() =>
      _ModelPrerequisiteDialogState();
}

class _ModelPrerequisiteDialogState
    extends ConsumerState<_ModelPrerequisiteDialog> {
  ModelStoreModel? _model;
  ModelDownloadProgress? _progress;
  String _phase = 'Loading verified catalog details';
  String? _error;
  bool _loading = true;
  bool _downloading = false;
  String? _taskId;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadModel);
  }

  Future<void> _loadModel() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final catalog = await ref.read(modelStoreCatalogProvider.future);
      final model = catalog.cast<ModelStoreModel?>().firstWhere(
            (item) => item?.id == widget.modelId,
            orElse: () => null,
          );
      if (model == null) {
        final service = ref.read(modelStoreServiceProvider);
        final sourceError = widget.modelId == 'whisper-tiny'
            ? service.lastSpeechCatalogError
            : service.lastOnDeviceCatalogError;
        if (sourceError != null) {
          throw StateError(
            'The required catalog source is unavailable: $sourceError',
          );
        }
        throw StateError(
          'The required model is not present in the current Cactus catalog.',
        );
      }
      if (mounted) setState(() => _model = model);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _download() async {
    final model = _model;
    if (model == null || _downloading) return;
    setState(() {
      _downloading = true;
      _error = null;
      _phase = 'Preparing secure download';
    });
    try {
      await ref.read(modelDownloadServiceProvider).downloadManagedBundle(
            modelId: model.id,
            modelName: model.name,
            url: model.downloadUrl,
            archiveFilename: model.archiveFilename,
            catalogSizeMb: model.sizeMb,
            onProgress: (progress, phase) {
              if (!mounted) return;
              setState(() {
                _progress = progress;
                _phase = phase;
              });
            },
            onTaskCreated: (taskId) => _taskId = taskId,
          );
      ref.invalidate(installedStoreModelIdsProvider);
      await ref.read(modelManagerProvider.notifier).scanLocalModels();
      if (!mounted) return;
      Navigator.pop(context, ModelPrerequisiteResult.installed);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _error = error.toString();
        _phase = 'Download stopped';
      });
    }
  }

  Future<void> _cancelDownload() async {
    final taskId = _taskId;
    if (taskId == null) return;
    await ref.read(modelDownloadServiceProvider).cancelManagedDownload(taskId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final model = _model;
    final progress = _progress;
    return AlertDialog(
      icon: Icon(Icons.download_for_offline, color: theme.colorScheme.primary),
      title: Text(widget.title),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.explanation),
              const SizedBox(height: 16),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else if (model != null)
                Card.outlined(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          model.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text('Required model ID: ${model.id}'),
                        Text('Download size: about ${model.sizeMb} MB'),
                        Text('Source: ${model.source}'),
                        Text(
                          'License: ${model.license ?? 'not supplied by catalog'}',
                        ),
                      ],
                    ),
                  ),
                ),
              if (_downloading) ...[
                const SizedBox(height: 16),
                Text(_phase, style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: progress == null || progress.totalBytes <= 0
                      ? null
                      : progress.progress,
                ),
                const SizedBox(height: 6),
                Text(
                  progress == null
                      ? 'Starting…'
                      : '${_megabytes(progress.downloadedBytes)} of '
                          '${progress.totalBytes > 0 ? _megabytes(progress.totalBytes) : 'unknown size'}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
              if (!_downloading) ...[
                const SizedBox(height: 12),
                Text(
                  'You can choose Not now and install a compatible model later from Model Store.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (_downloading)
          TextButton(
            onPressed: _cancelDownload,
            child: const Text('Cancel download'),
          ),
        if (!_downloading)
          TextButton(
            onPressed: () => Navigator.pop(
              context,
              ModelPrerequisiteResult.skipped,
            ),
            child: const Text('Not now'),
          ),
        if (!_downloading)
          OutlinedButton(
            onPressed: () => Navigator.pop(
              context,
              ModelPrerequisiteResult.chooseAnother,
            ),
            child: const Text('Choose another'),
          ),
        if (!_downloading && _error != null)
          TextButton(onPressed: _loadModel, child: const Text('Retry catalog')),
        FilledButton.icon(
          onPressed:
              _loading || _downloading || model == null ? null : _download,
          icon: const Icon(Icons.download),
          label: Text(_downloading ? 'Downloading…' : 'Download now'),
        ),
      ],
    );
  }

  String _megabytes(int bytes) =>
      '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
}
