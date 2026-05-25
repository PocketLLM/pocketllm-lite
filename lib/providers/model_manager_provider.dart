import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../models/local_model.dart';
import '../services/model_storage_service.dart';
import '../services/llama_inference_service.dart';

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
      activeLoadedId: activeLoadedId,     // Can be set to null
      error: error,
    );
  }
}

class ModelManagerNotifier extends Notifier<ModelManagerState> {
  @override
  ModelManagerState build() {
    return ModelManagerState(
      models: {
        'llama-3.2-1b': const LocalModel(
          id: 'llama-3.2-1b',
          name: 'Llama 3.2 1B Instruct (Meta)',
          downloadUrl: 'https://huggingface.co/lmstudio-community/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf',
          fileSizeInBytes: 1240000000,
        ),
        'llama-3.2-3b': const LocalModel(
          id: 'llama-3.2-3b',
          name: 'Llama 3.2 3B Instruct (Meta)',
          downloadUrl: 'https://huggingface.co/lmstudio-community/Llama-3.2-3B-Instruct-GGUF/resolve/main/Llama-3.2-3B-Instruct-Q4_K_M.gguf',
          fileSizeInBytes: 2020000000,
        ),
        'gemma-2-2b': const LocalModel(
          id: 'gemma-2-2b',
          name: 'Gemma 2 2B IT (Google)',
          downloadUrl: 'https://huggingface.co/lmstudio-community/gemma-2-2b-it-GGUF/resolve/main/gemma-2-2b-it-Q4_K_M.gguf',
          fileSizeInBytes: 1600000000,
        ),
        'qwen-2.5-1.5b': const LocalModel(
          id: 'qwen-2.5-1.5b',
          name: 'Qwen 2.5 1.5B Chat (Alibaba)',
          downloadUrl: 'https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf',
          fileSizeInBytes: 1620000000,
        ),
        'phi-3.5-mini': const LocalModel(
          id: 'phi-3.5-mini',
          name: 'Phi-3.5 Mini Instruct (Microsoft)',
          downloadUrl: 'https://huggingface.co/lmstudio-community/Phi-3.5-mini-instruct-GGUF/resolve/main/Phi-3.5-mini-instruct-Q4_K_M.gguf',
          fileSizeInBytes: 2200000000,
        ),
      },
    );
  }

  CancelToken? _cancelToken;

  /// Starts downloading the local GGUF model and updates progress in the Riverpod store
  Future<void> triggerDownload(String id) async {
    final model = state.models[id];
    if (model == null || state.activeDownloadId != null) return;

    _cancelToken = CancelToken();
    state = state.copyWith(
      activeDownloadId: id,
      models: Map<String, LocalModel>.from(state.models)
        ..[id] = model.copyWith(
          status: DownloadStatus.downloading,
          downloadProgress: 0.0,
        ),
    );

    try {
      final downloadedPath = await ModelStorageService.instance.downloadModel(
        modelId: id,
        url: model.downloadUrl,
        cancelToken: _cancelToken,
        onProgress: (progress, bytesReceived, totalBytes) {
          final updatedModel = state.models[id];
          if (updatedModel != null) {
            state = state.copyWith(
              models: Map<String, LocalModel>.from(state.models)
                ..[id] = updatedModel.copyWith(
                  downloadProgress: progress,
                ),
            );
          }
        },
      );

      final finalModel = state.models[id];
      if (finalModel != null) {
        state = state.copyWith(
          activeDownloadId: null,
          models: Map<String, LocalModel>.from(state.models)
            ..[id] = finalModel.copyWith(
              status: DownloadStatus.downloaded,
              downloadProgress: 1.0,
              localPath: downloadedPath,
            ),
        );
      }
    } catch (e) {
      final abortedModel = state.models[id];
      if (abortedModel != null) {
        state = state.copyWith(
          activeDownloadId: null,
          error: e.toString(),
          models: Map<String, LocalModel>.from(state.models)
            ..[id] = abortedModel.copyWith(
              status: DownloadStatus.notDownloaded,
              downloadProgress: 0.0,
            ),
        );
      }
    }
  }

  /// Cancels the current downloading model queue
  void cancelActiveDownload() {
    if (_cancelToken != null && !_cancelToken!.isCancelled) {
      _cancelToken!.cancel('User cancelled download');
      _cancelToken = null;
    }
  }

  /// Safely registers an externally selected GGUF file
  void addCustomImport(String path, String name) {
    final customId = 'custom-${DateTime.now().millisecondsSinceEpoch}';
    final customModel = LocalModel(
      id: customId,
      name: name,
      downloadUrl: '',
      fileSizeInBytes: 0,
      localPath: path,
      status: DownloadStatus.downloaded,
      downloadProgress: 1.0,
      isCustomImport: true,
    );

    state = state.copyWith(
      models: Map<String, LocalModel>.from(state.models)..[customId] = customModel,
    );
  }

  /// Memory maps the selected model file into RAM/GPU context
  Future<bool> loadModelToRAM(String id) async {
    final model = state.models[id];
    if (model == null || model.localPath == null) return false;

    try {
      final success = await LlamaInferenceService.instance.loadModelContext(
        model.localPath!,
        2048, // context window limit
      );
      if (success) {
        state = state.copyWith(
          activeLoadedId: id,
        );
        return true;
      }
      return false;
    } catch (e) {
      state = state.copyWith(
        error: 'Failed to load model memory mapping: $e',
      );
      return false;
    }
  }

  /// Unloads model context and frees accelerator cache
  void unloadActiveModel() {
    LlamaInferenceService.instance.unloadCurrentModel();
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

    if (model.localPath != null) {
      await ModelStorageService.instance.deleteModel(model.localPath!);
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
final modelManagerProvider = NotifierProvider<ModelManagerNotifier, ModelManagerState>(
  ModelManagerNotifier.new,
);
