import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../core/providers.dart';
import '../core/constants/app_constants.dart';
import '../models/local_model.dart';
import '../models/model_manifest.dart';
import '../services/model_storage_service.dart';

class ModelManagerState {
  static const _unset = Object();

  final Map<String, LocalModel> models;
  final String? activeDownloadId;
  final String? activeLoadedId;
  final String? error;

  const ModelManagerState({
    required this.models,
    this.activeDownloadId,
    this.activeLoadedId,
    this.error,
  });

  ModelManagerState copyWith({
    Map<String, LocalModel>? models,
    Object? activeDownloadId = _unset,
    Object? activeLoadedId = _unset,
    Object? error = _unset,
  }) {
    return ModelManagerState(
      models: models ?? this.models,
      activeDownloadId: identical(activeDownloadId, _unset)
          ? this.activeDownloadId
          : activeDownloadId as String?,
      activeLoadedId: identical(activeLoadedId, _unset)
          ? this.activeLoadedId
          : activeLoadedId as String?,
      error: identical(error, _unset) ? this.error : error as String?,
    );
  }
}

class ModelManagerNotifier extends Notifier<ModelManagerState> {
  @override
  ModelManagerState build() {
    Future.microtask(scanLocalModels);
    return const ModelManagerState(models: {});
  }

  Future<void> scanLocalModels() async {
    try {
      final modelDirectory =
          await ModelStorageService.instance.getModelDirectory();
      final persisted = _loadPersistedManifests();
      final discovered = <String, LocalModel>{};
      await for (final entity in modelDirectory.list(followLinks: false)) {
        if (entity is Directory) {
          if (p.basename(entity.path).startsWith('.')) continue;
          final discoveredFiles = await entity
              .list(recursive: true, followLinks: false)
              .where((item) =>
                  item is File && item.path.toLowerCase().endsWith('.gguf'))
              .cast<File>()
              .toList();
          final files = <File>[];
          for (final file in discoveredFiles) {
            if (await ModelStorageService.instance.isValidGGUFFile(file.path)) {
              files.add(file);
            }
          }
          if (files.isEmpty || files.length != discoveredFiles.length) continue;
          final id = p.basename(entity.path);
          final size = await _sumFileSizes(files);
          final manifest = persisted[id] ??
              _manifestForLocalFile(
                id: id,
                filename: p.basename(files.first.path),
                sizeBytes: size,
                status: ModelSupportStatus.installedUntested,
              );
          discovered[id] = _localModelFromManifest(
            manifest,
            localPath: files.first.path,
            customImport: manifest.source != 'cactus-download',
          );
        } else if (entity is File &&
            entity.path.toLowerCase().endsWith('.gguf')) {
          // Older builds stored GGUF files directly in /models. Keep them
          // visible, but do not claim the folder-based Cactus path is runnable.
          final id = p.basenameWithoutExtension(entity.path);
          final existing = persisted[id];
          final manifest = (existing ??
                  _manifestForLocalFile(
                    id: id,
                    filename: p.basename(entity.path),
                    sizeBytes: await entity.length(),
                    status: ModelSupportStatus.backendUnsupported,
                  ))
              .copyWith(status: ModelSupportStatus.backendUnsupported);
          discovered[id] = _localModelFromManifest(
            manifest,
            localPath: entity.path,
            customImport: true,
          );
        }
      }
      state = state.copyWith(models: discovered, error: null);
      await _persistManifests(
        discovered.values.map((model) => model.manifest!).toList(),
      );
    } catch (error) {
      debugPrint('Error scanning local models: $error');
      state = state.copyWith(
        error: 'Installed models could not be scanned: $error',
      );
    }
  }

  Future<void> triggerDownload(String id) async {
    final model = state.models[id];
    if (model == null) return;
    state = state.copyWith(
      error: 'Direct catalog download is unavailable for this entry. '
          'Use Explore Hugging Face, verify a GGUF file, and import it.',
    );
  }

  void cancelActiveDownload() {
    state = state.copyWith(activeDownloadId: null);
  }

  void addCustomImport(
    String path,
    String name, {
    ModelManifest? manifest,
  }) {
    final file = File(path);
    final id = p.basename(p.dirname(path));
    final resolvedManifest = manifest ??
        _manifestForLocalFile(
          id: id,
          filename: name,
          sizeBytes: file.existsSync() ? file.lengthSync() : 0,
          status: ModelSupportStatus.installedUntested,
        );
    final model = _localModelFromManifest(
      resolvedManifest,
      localPath: path,
      customImport: true,
    );
    state = state.copyWith(
      models: Map<String, LocalModel>.from(state.models)..[id] = model,
      error: null,
    );
    unawaited(_persistManifests(
      state.models.values
          .map((entry) => entry.manifest)
          .whereType<ModelManifest>()
          .toList(),
    ));
  }

  Future<bool> loadModelToRAM(String id) async {
    final model = state.models[id];
    if (model == null || model.status != DownloadStatus.downloaded) {
      state = state.copyWith(error: 'Model "$id" is not installed.');
      return false;
    }
    if (model.manifest?.status == ModelSupportStatus.backendUnsupported) {
      state = state.copyWith(
        error: 'This legacy GGUF is not in a Cactus model folder. '
            'Re-import it to register a runnable model path.',
      );
      return false;
    }

    try {
      final localService = ref.read(inferenceServiceFactoryProvider).local();
      await localService.loadModel(id);
      final verifiedManifest = model.manifest!.copyWith(
        status: ModelSupportStatus.tested,
        capabilities: {
          ...model.manifest!.capabilities,
          'Text generation',
        }.toList(growable: false),
        lastVerified: DateTime.now().toUtc(),
      );
      final verifiedModel = model.copyWith(
        manifest: verifiedManifest,
        capabilities: verifiedManifest.capabilities,
      );
      state = state.copyWith(
        activeLoadedId: id,
        models: Map<String, LocalModel>.from(state.models)
          ..[id] = verifiedModel,
        error: null,
      );
      await _persistManifests(
        state.models.values.map((entry) => entry.manifest!).toList(),
      );
      return true;
    } catch (error) {
      state = state.copyWith(
        error: 'Failed to load model context: $error',
      );
      return false;
    }
  }

  void unloadActiveModel() {
    final modelId = state.activeLoadedId;
    if (modelId != null) {
      unawaited(
        ref.read(inferenceServiceFactoryProvider).local().unloadModel(modelId),
      );
    }
    state = state.copyWith(activeLoadedId: null);
  }

  Future<void> purgeModel(String id) async {
    final model = state.models[id];
    if (model == null) return;
    if (state.activeLoadedId == id) unloadActiveModel();
    final localPath = model.localPath;
    if (localPath != null) {
      await ModelStorageService.instance.deleteRegisteredModel(localPath);
    }
    final updated = Map<String, LocalModel>.from(state.models)..remove(id);
    state = state.copyWith(models: updated, error: null);
    await _persistManifests(
      updated.values.map((entry) => entry.manifest!).toList(),
    );
  }

  Map<String, ModelManifest> _loadPersistedManifests() {
    final raw = ref.read(storageServiceProvider).getSetting(
      AppConstants.modelManifestRegistryKey,
      defaultValue: const [],
    );
    if (raw is! List) return {};
    final manifests = <String, ModelManifest>{};
    for (final item in raw) {
      if (item is! Map) continue;
      try {
        final manifest = ModelManifest.fromJson(
          Map<String, dynamic>.from(item),
        );
        manifests[manifest.id] = manifest;
      } catch (_) {
        // A malformed manifest cannot make valid installed models disappear.
      }
    }
    return manifests;
  }

  Future<void> _persistManifests(List<ModelManifest> manifests) {
    return ref.read(storageServiceProvider).saveSetting(
          AppConstants.modelManifestRegistryKey,
          manifests
              .map((manifest) => manifest.toJson())
              .toList(growable: false),
        );
  }

  ModelManifest _manifestForLocalFile({
    required String id,
    required String filename,
    required int sizeBytes,
    required ModelSupportStatus status,
  }) {
    final quantization = RegExp(
      r'(Q\d(?:_[A-Z0-9]+)+|F16|F32|BF16)',
      caseSensitive: false,
    ).firstMatch(filename)?.group(0)?.toUpperCase();
    return ModelManifest(
      id: id,
      displayName: p.basenameWithoutExtension(filename),
      source: 'local-import',
      quantization: quantization,
      fileSizeBytes: sizeBytes,
      backendCompatibility: const ['Cactus folder runtime'],
      minimumBackendVersion: '1.3.0',
      status: status,
      lastVerified: DateTime.now().toUtc(),
    );
  }

  LocalModel _localModelFromManifest(
    ModelManifest manifest, {
    required String localPath,
    required bool customImport,
  }) {
    return LocalModel(
      id: manifest.id,
      name: manifest.displayName,
      downloadUrl: '',
      fileSizeInBytes: manifest.fileSizeBytes,
      localPath: localPath,
      status: DownloadStatus.downloaded,
      downloadProgress: 1,
      isCustomImport: customImport,
      description: manifest.status.label,
      provider: manifest.provider,
      family: manifest.family,
      capabilities: manifest.capabilities,
      manifest: manifest,
    );
  }

  Future<int> _sumFileSizes(List<File> files) async {
    var total = 0;
    for (final file in files) {
      total += await file.length();
    }
    return total;
  }
}

final modelManagerProvider =
    NotifierProvider<ModelManagerNotifier, ModelManagerState>(
  ModelManagerNotifier.new,
);
