import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/m3_app_bar.dart';
import '../../../core/widgets/m3_section_header.dart';
import 'dart:async';
import '../../../models/local_model.dart';
import '../../../providers/model_manager_provider.dart';
import '../../../services/model_storage_service.dart';
import '../../../services/llama_inference_service.dart';

class ModelCatalogScreen extends ConsumerStatefulWidget {
  const ModelCatalogScreen({super.key});

  @override
  ConsumerState<ModelCatalogScreen> createState() => _ModelCatalogScreenState();
}

class _ModelCatalogScreenState extends ConsumerState<ModelCatalogScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// System resiliency: Listen to abrupt memory pressure events from the OS
  /// and purge active model memory context before getting terminated.
  @override
  void didHaveMemoryPressure() {
    super.didHaveMemoryPressure();
    final state = ref.read(modelManagerProvider);
    if (state.activeLoadedId != null) {
      ref.read(modelManagerProvider.notifier).unloadActiveModel();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Memory Pressure Warning: Current local model unloaded from RAM to prevent crash.',
                ),
              ),
            ],
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Picker and scoped URI importer for custom offline GGUFs
  Future<void> _handleCustomImport() async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any, // GGUF isn't a standard extension type on all mobile platforms, pick general
      );

      if (result == null) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Validating and copying custom GGUF file...'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      final importedFile = await ModelStorageService.instance.importExternalGGUF(result);
      if (importedFile != null) {
        final String name = result.files.first.name;
        ref.read(modelManagerProvider.notifier).addCustomImport(importedFile.path, name);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Imported "$name" successfully!'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          icon: Icon(Icons.error_outline_rounded, color: Theme.of(context).colorScheme.error),
          title: const Text('Import Failed'),
          content: Text(e.toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(modelManagerProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    ref.listen<String?>(
      modelManagerProvider.select((s) => s.error),
      (previous, next) {
        if (next != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.error_outline_rounded, color: colorScheme.onError),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Operation failed: $next',
                      style: TextStyle(color: colorScheme.onError),
                    ),
                  ),
                ],
              ),
              backgroundColor: colorScheme.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
    );

    // Separate pre-configured catalog models from custom imported models
    final catalogModels = state.models.values.where((m) => !m.isCustomImport).toList();
    final customModels = state.models.values.where((m) => m.isCustomImport).toList();

    return Scaffold(
      appBar: M3AppBar(
        title: 'Local GGUF Models',
        subtitle: 'Compile and run offline llama.cpp inference',
        onBack: () => context.pop(),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            tooltip: 'GGUF Local Help',
            onPressed: () {
              HapticFeedback.lightImpact();
              context.push('/settings/model-help');
            },
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Premium Custom Import Header Panel
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                elevation: 0,
                color: colorScheme.primaryContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28.0),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.sd_storage_rounded,
                            color: colorScheme.onPrimaryContainer,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Import Local GGUF Files',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Already have a quantized Llama, Gemma or Qwen model downloaded? Pick it from your file explorer to register it instantly without repeating downloads.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _handleCustomImport,
                        style: FilledButton.styleFrom(
                          backgroundColor: colorScheme.onPrimaryContainer,
                          foregroundColor: colorScheme.primaryContainer,
                        ),
                        icon: const Icon(Icons.file_open_rounded),
                        label: const Text('Browse Files'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Standard Catalog Models Section
          const SliverToBoxAdapter(
            child: M3SectionHeader(
              title: 'Standard GGUF Catalog',
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final model = catalogModels[index];
                return _buildModelCatalogRow(context, model, state);
              },
              childCount: catalogModels.length,
            ),
          ),

          // Custom Imported Models Section
          if (customModels.isNotEmpty) ...[
            const SliverToBoxAdapter(
              child: M3SectionHeader(
                title: 'Custom Imported GGUF Models',
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final model = customModels[index];
                  return _buildModelCatalogRow(context, model, state);
                },
                childCount: customModels.length,
              ),
            ),
          ],
          
          const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
        ],
      ),
    );
  }

  /// Builds a modern Material 3 list card for GGUF model controls
  Widget _buildModelCatalogRow(BuildContext context, LocalModel model, ModelManagerState state) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDownloading = state.activeDownloadId == model.id;
    final isLoaded = state.activeLoadedId == model.id;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      elevation: 0,
      color: isLoaded
          ? colorScheme.tertiaryContainer.withValues(alpha: 0.25)
          : colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isLoaded
              ? colorScheme.tertiary
              : colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: isLoaded ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        model.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (model.isCustomImport) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Imported',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            model.formattedSize,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _buildActionWidget(context, model, state),
              ],
            ),

            // Download progress bar
            if (isDownloading) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: model.downloadProgress,
                      borderRadius: BorderRadius.circular(4),
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${(model.downloadProgress * 100).toStringAsFixed(0)}%',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Downloading components...',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      ref.read(modelManagerProvider.notifier).cancelActiveDownload();
                    },
                    icon: const Icon(Icons.cancel_rounded, size: 16),
                    label: const Text('Cancel'),
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.error,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(50, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ],

            // Active loading status chip
            if (isLoaded) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.bolt_rounded,
                    color: colorScheme.tertiary,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Loaded in RAM Accelerator context',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.tertiary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Builds appropriate action button (download, loading memory, unload or purge)
  Widget _buildActionWidget(BuildContext context, LocalModel model, ModelManagerState state) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isLoaded = state.activeLoadedId == model.id;
    final isAnyDownloading = state.activeDownloadId != null;

    if (model.status == DownloadStatus.notDownloaded) {
      return IconButton.filledTonal(
        onPressed: isAnyDownloading
            ? null
            : () {
                HapticFeedback.selectionClick();
                ref.read(modelManagerProvider.notifier).triggerDownload(model.id);
              },
        icon: const Icon(Icons.download_rounded),
        tooltip: 'Download GGUF model',
      );
    }

    if (model.status == DownloadStatus.downloading) {
      return const SizedBox(
        width: 40,
        height: 40,
        child: Padding(
          padding: EdgeInsets.all(8.0),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    // Downloaded or Imported: Show Load/Unload, Test and Delete actions
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            _showTestModelDialog(context, model);
          },
          icon: Icon(Icons.offline_bolt_outlined, color: colorScheme.primary),
          tooltip: 'Test model speed & completion',
        ),
        const SizedBox(width: 4),
        if (isLoaded)
          IconButton.filled(
            onPressed: () {
              HapticFeedback.selectionClick();
              ref.read(modelManagerProvider.notifier).unloadActiveModel();
            },
            style: IconButton.styleFrom(
              backgroundColor: colorScheme.tertiary,
              foregroundColor: colorScheme.onTertiary,
            ),
            icon: const Icon(Icons.power_settings_new_rounded),
            tooltip: 'Unload from memory',
          )
        else
          IconButton.filledTonal(
            onPressed: () async {
              HapticFeedback.selectionClick();
              final success = await ref.read(modelManagerProvider.notifier).loadModelToRAM(model.id);
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('"${model.name}" loaded in RAM successfully!'),
                    backgroundColor: colorScheme.primary,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            icon: const Icon(Icons.power_rounded),
            tooltip: 'Load into memory',
          ),
        const SizedBox(width: 4),
        IconButton(
          onPressed: () {
            HapticFeedback.selectionClick();
            _showDeleteConfirmDialog(context, model);
          },
          icon: Icon(Icons.delete_forever_rounded, color: colorScheme.error),
          tooltip: 'Purge model from device',
        ),
      ],
    );
  }

  /// Double check safety warning dialogue before deleting gigabyte models
  Future<void> _showDeleteConfirmDialog(BuildContext context, LocalModel model) async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.delete_sweep_rounded, color: colorScheme.error, size: 28),
        title: const Text('Purge Model File?'),
        content: Text(
          'This will permanently delete "${model.name}" and release ${model.formattedSize} of disk space. You will have to redownload or re-import the file if needed again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep File'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(modelManagerProvider.notifier).purgeModel(model.id);
            },
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
            ),
            child: const Text('Purge permanently'),
          ),
        ],
      ),
    );
  }

  /// Interactive modal dialog executing live offline FFI token generation tests
  Future<void> _showTestModelDialog(BuildContext context, LocalModel model) async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    await showDialog(
      context: context,
      builder: (context) {
        String testPrompt = 'Say Hello and introduce yourself in one short sentence.';
        String generatedText = '';
        bool isTesting = false;
        double tps = 0.0;
        int ttftMs = 0;
        StreamSubscription<String>? subscription;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            void startTest() {
              setDialogState(() {
                isTesting = true;
                generatedText = 'Computing local FFI vectors...';
                tps = 0.0;
                ttftMs = 0;
              });

              final startTime = DateTime.now();
              DateTime? firstTokenTime;
              int tokenCount = 0;

              subscription = LlamaInferenceService.instance
                  .streamCompletion(testPrompt)
                  .listen(
                (token) {
                  final now = DateTime.now();
                  if (firstTokenTime == null) {
                    firstTokenTime = now;
                    ttftMs = now.difference(startTime).inMilliseconds;
                    generatedText = ''; // Clear loading text
                  }
                  
                  tokenCount++;
                  final elapsed = now.difference(startTime).inSeconds;
                  if (elapsed > 0) {
                    tps = tokenCount / elapsed;
                  } else {
                    tps = tokenCount * 10.0;
                  }

                  setDialogState(() {
                    generatedText += token;
                  });
                },
                onError: (err) {
                  setDialogState(() {
                    generatedText = 'Error during native execution: $err';
                    isTesting = false;
                  });
                },
                onDone: () {
                  final now = DateTime.now();
                  final elapsedMs = now.difference(startTime).inMilliseconds;
                  if (elapsedMs > 0) {
                    tps = (tokenCount * 1000) / elapsedMs;
                  }
                  setDialogState(() {
                    isTesting = false;
                  });
                },
              );
            }

            return AlertDialog(
              icon: Icon(Icons.offline_bolt_rounded, color: colorScheme.primary, size: 32),
              title: Text('Test "${model.name}"'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Prompt:',
                    style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      testPrompt,
                      style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Offline Response Stream:',
                        style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (isTesting)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    height: 120,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        generatedText.isEmpty ? 'Tap "Run Inference Test" to begin.' : generatedText,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: generatedText.startsWith('Error') ? colorScheme.error : null,
                        ),
                      ),
                    ),
                  ),
                  if (tps > 0 || ttftMs > 0) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Latency: ${ttftMs}ms',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                          ),
                          Text(
                            'Speed: ${tps.toStringAsFixed(1)} tokens/s',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    subscription?.cancel();
                    Navigator.pop(context);
                  },
                  child: const Text('Close'),
                ),
                FilledButton.icon(
                  onPressed: isTesting ? null : startTest,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Run Inference Test'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
