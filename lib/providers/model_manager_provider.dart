import 'dart:io';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';
import 'package:cactus/cactus.dart';
import '../models/local_model.dart';
import '../services/model_storage_service.dart';
import '../core/providers.dart';

class ModelManagerState {
  final Map<String, LocalModel> models;
  final String? activeDownloadId;
  final String? activeLoadedId;
  final String? error;

  ModelManagerState({
    required this.models,
    this.activeDownloadId,
    this.activeLoadedId,
    this.error,
  });

  ModelManagerState copyWith({
    Map<String, LocalModel>? models,
    String? activeDownloadId,
    String? activeLoadedId,
    String? error,
  }) {
    return ModelManagerState(
      models: models ?? this.models,
      activeDownloadId: activeDownloadId, // Can be set to null
      activeLoadedId: activeLoadedId, // Can be set to null
      error: error,
    );
  }
}

class ModelManagerNotifier extends Notifier<ModelManagerState> {
  @override
  ModelManagerState build() {
    // Schedule local models scan after state initialization
    Future.microtask(() => _scanLocalModels());

    return ModelManagerState(
      models: {
        'gemma3-270m': const LocalModel(
          id: 'gemma3-270m',
          name: 'Gemma 3 270M IT (Google)',
          downloadUrl: '',
          fileSizeInBytes: 180355072,
          provider: 'Google',
          family: 'Gemma 3',
          description:
              'An ultra-compact 270M parameter instruct model optimized for high-speed, light resource environments. Perfect for quick conversational queries and devices with extremely limited RAM.',
          capabilities: [
            'Text Generation',
            'Summarization',
            'Conversational Flow',
            'Extremely Lightweight'
          ],
          benchmarks: {
            'MMLU': '42.1%',
            'GSM8K': '21.5%',
            'ARC-Challenge': '38.6%',
          },
        ),
        'gemma3-1b': const LocalModel(
          id: 'gemma3-1b',
          name: 'Gemma 3 1B IT (Google)',
          downloadUrl: '',
          fileSizeInBytes: 673153024,
          provider: 'Google',
          family: 'Gemma 3',
          description:
              'A next-generation 1B instruct model from Google delivering exceptional reasoning and instruction-following capability in a compact form factor.',
          capabilities: [
            'Coding Help',
            'Math & Logic',
            'Dialogue Flow',
            'Instruction Following'
          ],
          benchmarks: {
            'MMLU': '56.1%',
            'GSM8K': '62.8%',
            'HumanEval': '41.5%',
          },
        ),
        'gemma3-1b-pro': const LocalModel(
          id: 'gemma3-1b-pro',
          name: 'Gemma 3 1B Pro IT (Google)',
          downloadUrl: '',
          fileSizeInBytes: 1342177280,
          provider: 'Google',
          family: 'Gemma 3',
          description:
              'A professional-tier 1B instruct model offering higher context limits and expanded comprehension for complex logical and coding tasks.',
          capabilities: [
            'Complex Reasoning',
            'Advanced Math',
            'Multi-turn Chat',
            'Deep Analysis'
          ],
          benchmarks: {
            'MMLU': '64.5%',
            'GSM8K': '71.2%',
            'HumanEval': '52.3%',
          },
        ),
        'qwen3-0.6': const LocalModel(
          id: 'qwen3-0.6',
          name: 'Qwen 3 0.6B IT (Alibaba)',
          downloadUrl: '',
          fileSizeInBytes: 413138944,
          provider: 'Alibaba',
          family: 'Qwen 3',
          description:
              'A small and highly capable model from the latest Qwen series, optimized for fast on-device text generation and function calling.',
          capabilities: [
            'Tool Calling',
            'Bilingual',
            'Fast Inference',
            'Summarization'
          ],
          benchmarks: {
            'MMLU': '52.4%',
            'GSM8K': '44.8%',
            'HumanEval': '32.1%',
          },
        ),
        'qwen3-1.7': const LocalModel(
          id: 'qwen3-1.7',
          name: 'Qwen 3 1.7B IT (Alibaba)',
          downloadUrl: '',
          fileSizeInBytes: 1217396736,
          provider: 'Alibaba',
          family: 'Qwen 3',
          description:
              'A mid-sized powerhouse model from Alibaba, offering excellent performance across reasoning, coding, and tool use in under 1.2GB.',
          capabilities: [
            'Tool Calling',
            'Coding Assistance',
            'Math & Logic',
            'Multilingual'
          ],
          benchmarks: {
            'MMLU': '68.2%',
            'GSM8K': '80.5%',
            'HumanEval': '64.2%',
          },
        ),
        'qwen3-0.6-pro': const LocalModel(
          id: 'qwen3-0.6-pro',
          name: 'Qwen 3 0.6B Pro IT (Alibaba)',
          downloadUrl: '',
          fileSizeInBytes: 914358272,
          provider: 'Alibaba',
          family: 'Qwen 3',
          description:
              'A professional configuration of the Qwen 3 0.6B model, providing enhanced comprehension and reasoning capabilities.',
          capabilities: [
            'Bilingual',
            'Tool Use',
            'Complex Instruction',
            'Logical Chain'
          ],
          benchmarks: {
            'MMLU': '58.7%',
            'GSM8K': '55.3%',
            'HumanEval': '42.8%',
          },
        ),
        'qwen3-1.7-pro': const LocalModel(
          id: 'qwen3-1.7-pro',
          name: 'Qwen 3 1.7B Pro IT (Alibaba)',
          downloadUrl: '',
          fileSizeInBytes: 2651832320,
          provider: 'Alibaba',
          family: 'Qwen 3',
          description:
              'The top-tier 1.7B parameter model in the Qwen family, delivering state-of-the-art coding and mathematical reasoning on device.',
          capabilities: [
            'Advanced Coding',
            'Complex Math',
            'Tool Use',
            'Full Multilingual'
          ],
          benchmarks: {
            'MMLU': '72.1%',
            'GSM8K': '87.4%',
            'HumanEval': '78.5%',
          },
        ),
        'smollm2-360m': const LocalModel(
          id: 'smollm2-360m',
          name: 'SmolLM2 360M IT (Hugging Face)',
          downloadUrl: '',
          fileSizeInBytes: 238026752,
          provider: 'Hugging Face',
          family: 'SmolLM2',
          description:
              'An Apache 2.0 licensed, highly efficient 360M parameter model designed for lightweight conversational tasks and text operations on low-resource devices.',
          capabilities: [
            'Summarization',
            'Dialogue Flow',
            'Permissive License',
            'Lightweight'
          ],
          benchmarks: {
            'MMLU': '35.6%',
            'HellaSwag': '52.8%',
            'ARC-Challenge': '39.4%',
          },
        ),
        'lfm2-350m': const LocalModel(
          id: 'lfm2-350m',
          name: 'LFM 2 350M IT (Liquid AI)',
          downloadUrl: '',
          fileSizeInBytes: 244318208,
          provider: 'Liquid AI',
          family: 'LFM 2',
          description:
              'An ultra-compact and efficient model from the Liquid Foundation Model series, optimized for fast on-device chat and general queries.',
          capabilities: [
            'Dialogue Flow',
            'Fast Inference',
            'Low Memory',
            'Bilingual'
          ],
          benchmarks: {
            'MMLU': '45.1%',
            'GSM8K': '28.4%',
            'ARC-Challenge': '43.2%',
          },
        ),
        'lfm2-700m': const LocalModel(
          id: 'lfm2-700m',
          name: 'LFM 2 700M IT (Liquid AI)',
          downloadUrl: '',
          fileSizeInBytes: 489684992,
          provider: 'Liquid AI',
          family: 'LFM 2',
          description:
              'A mid-sized LFM model providing a strong balance of conversational depth, command execution, and memory footprint.',
          capabilities: [
            'Dialogue Flow',
            'Instruction Following',
            'Reasoning Chain',
            'Efficiency'
          ],
          benchmarks: {
            'MMLU': '54.2%',
            'GSM8K': '49.1%',
            'ARC-Challenge': '56.7%',
          },
        ),
        'lfm2-1.2b': const LocalModel(
          id: 'lfm2-1.2b',
          name: 'LFM 2 1.2B IT (Liquid AI)',
          downloadUrl: '',
          fileSizeInBytes: 757088256,
          provider: 'Liquid AI',
          family: 'LFM 2',
          description:
              'A premium 1.2B parameter model from Liquid AI, delivering advanced reasoning and text generation capabilities.',
          capabilities: [
            'Reasoning Chain',
            'Dialogue Flow',
            'Coding Help',
            'Math & Logic'
          ],
          benchmarks: {
            'MMLU': '61.2%',
            'GSM8K': '68.5%',
            'ARC-Challenge': '66.4%',
          },
        ),
        'lfm2-1.2b-tool': const LocalModel(
          id: 'lfm2-1.2b-tool',
          name: 'LFM 2 1.2B Tool IT (Liquid AI)',
          downloadUrl: '',
          fileSizeInBytes: 764411904,
          provider: 'Liquid AI',
          family: 'LFM 2',
          description:
              'LFM 2 1.2B configured specifically for tool calling and agentic workflows, enabling direct integration with device APIs.',
          capabilities: [
            'Tool Calling',
            'Action Planning',
            'Reasoning Chain',
            'Coding Help'
          ],
          benchmarks: {
            'MMLU': '60.5%',
            'GSM8K': '65.2%',
            'ARC-Challenge': '64.8%',
          },
        ),
        'lfm2-vl-450m': const LocalModel(
          id: 'lfm2-vl-450m',
          name: 'LFM 2 VL 450M IT (Liquid AI)',
          downloadUrl: '',
          fileSizeInBytes: 440401920,
          provider: 'Liquid AI',
          family: 'LFM 2 VL',
          description:
              'A vision-language model in the LFM family, allowing processing of both image and text inputs in a very compact footprint.',
          capabilities: [
            'Multimodal',
            'Image Analysis',
            'Visual Q&A',
            'Lightweight'
          ],
          benchmarks: {
            'MMLU': '48.9%',
            'MMMU': '31.2%',
            'ARC-Challenge': '44.8%',
          },
        ),
        'lfm2-vl-1.6b': const LocalModel(
          id: 'lfm2-vl-1.6b',
          name: 'LFM 2 VL 1.6B IT (Liquid AI)',
          downloadUrl: '',
          fileSizeInBytes: 1509949440,
          provider: 'Liquid AI',
          family: 'LFM 2 VL',
          description:
              'A highly capable multimodal model, offering deep visual reasoning, OCR, and complex query resolution over images.',
          capabilities: [
            'Multimodal',
            'Detailed OCR',
            'Image Reasoning',
            'Visual Coding'
          ],
          benchmarks: {
            'MMLU': '63.4%',
            'MMMU': '44.5%',
            'ARC-Challenge': '68.2%',
          },
        ),
        'lfm2-vl-450m-pro': const LocalModel(
          id: 'lfm2-vl-450m-pro',
          name: 'LFM 2 VL 450M Pro IT (Liquid AI)',
          downloadUrl: '',
          fileSizeInBytes: 513802240,
          provider: 'Liquid AI',
          family: 'LFM 2 VL',
          description:
              'A professional-grade configuration of the LFM 2 VL 450M model, providing improved spatial comprehension and logic.',
          capabilities: ['Multimodal', 'Visual QA', 'Spatial Analysis', 'OCR'],
          benchmarks: {
            'MMLU': '52.6%',
            'MMMU': '34.7%',
            'ARC-Challenge': '49.1%',
          },
        ),
        'lfm2-vl-1.6b-pro': const LocalModel(
          id: 'lfm2-vl-1.6b-pro',
          name: 'LFM 2 VL 1.6B Pro IT (Liquid AI)',
          downloadUrl: '',
          fileSizeInBytes: 1858076672,
          provider: 'Liquid AI',
          family: 'LFM 2 VL',
          description:
              'Liquid AI\'s flagship local vision model, offering state-of-the-art visual understanding and reasoning on device.',
          capabilities: [
            'Multimodal',
            'Spatial Coding',
            'Advanced OCR',
            'Complex Visual QA'
          ],
          benchmarks: {
            'MMLU': '67.8%',
            'MMMU': '48.9%',
            'ARC-Challenge': '72.5%',
          },
        ),
      },
    );
  }

  /// Scans local files and hooks into background downloader updates
  Future<void> _scanLocalModels() async {
    try {
      final lm = CactusLM();
      final liveModels = await lm.getModels();
      final updatedModels = Map<String, LocalModel>.from(state.models);

      for (final liveModel in liveModels) {
        final slug = liveModel.slug;
        if (updatedModels.containsKey(slug)) {
          final existing = updatedModels[slug]!;
          updatedModels[slug] = existing.copyWith(
            status: liveModel.isDownloaded
                ? DownloadStatus.downloaded
                : DownloadStatus.notDownloaded,
            downloadProgress: liveModel.isDownloaded ? 1.0 : 0.0,
            fileSizeInBytes: liveModel.sizeMb * 1024 * 1024,
            localPath: liveModel.isDownloaded ? slug : null,
          );
        } else {
          updatedModels[slug] = LocalModel(
            id: slug,
            name: liveModel.name,
            downloadUrl: '',
            fileSizeInBytes: liveModel.sizeMb * 1024 * 1024,
            localPath: liveModel.isDownloaded ? slug : null,
            status: liveModel.isDownloaded
                ? DownloadStatus.downloaded
                : DownloadStatus.notDownloaded,
            downloadProgress: liveModel.isDownloaded ? 1.0 : 0.0,
            description: 'A local model from Cactus directory.',
            provider: 'Cactus',
            family: 'Cactus',
            capabilities: [
              if (liveModel.supportsVision) 'Vision',
              if (liveModel.supportsToolCalling) 'Tool Calling',
              'Local Inference',
            ],
            benchmarks: const {},
          );
        }
      }

      final appDir = await getApplicationDocumentsDirectory();
      final docModelsDir = Directory('${appDir.path}/models');
      if (await docModelsDir.exists()) {
        final List<FileSystemEntity> files = await docModelsDir.list().toList();
        for (final file in files) {
          if (file is File && file.path.endsWith('.gguf')) {
            final fileName = p.basename(file.path);
            final modelId = p.basenameWithoutExtension(file.path);

            if (updatedModels.containsKey(modelId)) {
              final existing = updatedModels[modelId]!;
              updatedModels[modelId] = existing.copyWith(
                status: DownloadStatus.downloaded,
                downloadProgress: 1.0,
                localPath: file.path,
              );
            } else {
              updatedModels[modelId] = LocalModel(
                id: modelId,
                name: fileName,
                downloadUrl: '',
                fileSizeInBytes: await file.length(),
                localPath: file.path,
                status: DownloadStatus.downloaded,
                downloadProgress: 1.0,
                isCustomImport: true,
              );
            }
          }
        }
      }

      state = state.copyWith(models: updatedModels);
    } catch (e) {
      debugPrint('Error scanning local models: $e');
    }
  }

  /// Starts downloading the local GGUF model and updates progress in the Riverpod store
  Future<void> triggerDownload(String id) async {
    final model = state.models[id];
    if (model == null || state.activeDownloadId != null) return;

    state = state.copyWith(
      activeDownloadId: id,
      models: Map<String, LocalModel>.from(state.models)
        ..[id] = model.copyWith(
          status: DownloadStatus.downloading,
          downloadProgress: 0.0,
        ),
    );

    // Watchdog timer to clear stuck-state
    Timer? watchdog;
    void startWatchdog() {
      watchdog?.cancel();
      watchdog = Timer(const Duration(seconds: 45), () {
        debugPrint('Download watchdog triggered for $id - timing out.');
        final currentModel = state.models[id];
        if (currentModel != null &&
            currentModel.status == DownloadStatus.downloading) {
          state = state.copyWith(
            activeDownloadId: null,
            error: 'Download timed out/stuck for ${currentModel.name}.',
            models: Map<String, LocalModel>.from(state.models)
              ..[id] = currentModel.copyWith(
                status: DownloadStatus.notDownloaded,
                downloadProgress: 0.0,
              ),
          );
        }
      });
    }

    startWatchdog();

    try {
      final lm = CactusLM();
      await lm.downloadModel(
        model: id,
        downloadProcessCallback: (progress, status, isError) {
          startWatchdog();

          final currentModel = state.models[id];
          if (currentModel == null) return;

          if (isError) {
            watchdog?.cancel();
            state = state.copyWith(
              activeDownloadId: null,
              error: 'Download failed: $status',
              models: Map<String, LocalModel>.from(state.models)
                ..[id] = currentModel.copyWith(
                  status: DownloadStatus.notDownloaded,
                  downloadProgress: 0.0,
                ),
            );
          } else {
            state = state.copyWith(
              activeDownloadId: id,
              models: Map<String, LocalModel>.from(state.models)
                ..[id] = currentModel.copyWith(
                  status: DownloadStatus.downloading,
                  downloadProgress: progress ?? currentModel.downloadProgress,
                ),
            );
          }
        },
      );

      watchdog?.cancel();
      final currentModel = state.models[id];
      if (currentModel != null) {
        state = state.copyWith(
          activeDownloadId: null,
          models: Map<String, LocalModel>.from(state.models)
            ..[id] = currentModel.copyWith(
              status: DownloadStatus.downloaded,
              downloadProgress: 1.0,
              localPath: id,
            ),
        );
      }
    } catch (e) {
      watchdog?.cancel();
      final currentModel = state.models[id];
      if (currentModel != null) {
        state = state.copyWith(
          activeDownloadId: null,
          error: e.toString(),
          models: Map<String, LocalModel>.from(state.models)
            ..[id] = currentModel.copyWith(
              status: DownloadStatus.notDownloaded,
              downloadProgress: 0.0,
            ),
        );
      }
    }
  }

  /// Cancels the current downloading model queue (no-op as local downloads are self-contained)
  void cancelActiveDownload() {}

  /// Safely registers an externally selected GGUF file
  void addCustomImport(String path, String name) {
    final customModel = LocalModel(
      id: name,
      name: name,
      downloadUrl: '',
      fileSizeInBytes: File(path).existsSync() ? File(path).lengthSync() : 0,
      localPath: path,
      status: DownloadStatus.downloaded,
      downloadProgress: 1.0,
      isCustomImport: true,
    );

    state = state.copyWith(
      models: Map<String, LocalModel>.from(state.models)..[name] = customModel,
    );
  }

  /// Memory maps the selected model file into RAM/GPU context
  Future<bool> loadModelToRAM(String id) async {
    final model = state.models[id];
    if (model == null) return false;

    try {
      final localService = ref.read(inferenceServiceFactoryProvider).local();
      await localService.loadModel(id);
      state = state.copyWith(
        activeLoadedId: id,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        error: 'Failed to load model context: $e',
      );
      return false;
    }
  }

  /// Unloads model context and frees accelerator cache
  void unloadActiveModel() {
    final localService = ref.read(inferenceServiceFactoryProvider).local();
    if (state.activeLoadedId != null) {
      localService.unloadModel(state.activeLoadedId!);
    }
    state = state.copyWith(
      activeLoadedId: null,
    );
  }

  /// Cleans up local disk storage and removes custom imports
  Future<void> purgeModel(String id) async {
    final model = state.models[id];
    if (model == null) return;

    if (state.activeLoadedId == id) {
      unloadActiveModel();
    }

    if (model.isCustomImport) {
      if (model.localPath != null) {
        await ModelStorageService.instance.deleteModel(model.localPath!);
      }
    } else {
      final appDir = await getApplicationDocumentsDirectory();
      final cactusModelFolder = Directory('${appDir.path}/models/$id');
      if (await cactusModelFolder.exists()) {
        await cactusModelFolder.delete(recursive: true);
      }
    }

    final updatedModels = Map<String, LocalModel>.from(state.models);
    if (model.isCustomImport) {
      updatedModels.remove(id);
    } else {
      updatedModels[id] = model.copyWith(
        status: DownloadStatus.notDownloaded,
        downloadProgress: 0.0,
        localPath: null,
      );
    }

    state = state.copyWith(
      models: updatedModels,
    );
  }
}

// Global Provider declaration
final modelManagerProvider =
    NotifierProvider<ModelManagerNotifier, ModelManagerState>(
  ModelManagerNotifier.new,
);
