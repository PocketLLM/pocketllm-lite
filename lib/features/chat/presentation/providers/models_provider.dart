import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers.dart';
import '../../../../providers/model_manager_provider.dart';
import '../../../../models/local_model.dart';
import '../../domain/models/ollama_model.dart';
import '../../../../services/openai_compatible_inference_service.dart';
import '../../../../services/ollama_service.dart';
import '../../../../services/remote_provider_registry.dart';

const _defaultModelDiscoveryTimeout = Duration(seconds: 4);

final modelDiscoveryTimeoutProvider = Provider<Duration>(
  (ref) => _defaultModelDiscoveryTimeout,
);

class UnifiedModel {
  final String id;
  final String name;
  final bool isLocal;
  final int size;
  final String backend;
  final bool supportsVision;

  UnifiedModel({
    required this.id,
    required this.name,
    required this.isLocal,
    required this.size,
    required this.backend,
    this.supportsVision = false,
  });
}

final modelsProvider = FutureProvider<List<OllamaModel>>((ref) async {
  final ollama = ref.watch(ollamaServiceProvider);
  final timeout = ref.watch(modelDiscoveryTimeoutProvider);
  return ollama.listModels().timeout(timeout);
});

final unifiedModelsProvider = FutureProvider<List<UnifiedModel>>((ref) async {
  final localState = ref.watch(modelManagerProvider);
  final List<UnifiedModel> list = [];

  // 1. Add all downloaded local models
  for (final m in localState.models.values) {
    if (m.status == DownloadStatus.downloaded) {
      list.add(UnifiedModel(
        id: m.id,
        name: m.name,
        isLocal: true,
        size: m.fileSizeInBytes,
        backend: 'local',
        supportsVision: m.manifest?.supportsVision == true,
      ));
    }
  }

  final discoveryTimeout = ref.watch(modelDiscoveryTimeoutProvider);
  final ollama = ref.watch(ollamaServiceProvider);
  final registry = ref.watch(remoteProviderRegistryProvider);
  List<RemoteProviderConfig> remoteConfigs;
  try {
    remoteConfigs = await registry.load().timeout(discoveryTimeout);
  } catch (_) {
    remoteConfigs = const [];
  }

  // Network discovery is best-effort and concurrent so one unreachable
  // endpoint cannot hold the model selector open indefinitely.
  final discoveries = <Future<List<UnifiedModel>>>[
    _discoverOllamaModels(ollama, discoveryTimeout),
    for (final config in remoteConfigs)
      _discoverRemoteModels(config, discoveryTimeout),
  ];
  for (final discovered in await Future.wait(discoveries)) {
    for (final model in discovered) {
      if (!list.any((item) => item.id == model.id)) {
        list.add(model);
      }
    }
  }

  return list;
});

Future<List<UnifiedModel>> _discoverOllamaModels(
  OllamaService ollama,
  Duration timeout,
) async {
  try {
    final List<OllamaModel> ollamaModels =
        await ollama.listModels().timeout(timeout);
    return [
      for (final model in ollamaModels)
        UnifiedModel(
          id: model.name,
          name: model.name,
          isLocal: false,
          size: model.size,
          backend: 'ollama',
          // The Ollama tags response does not declare input capabilities.
          // Keep image input unavailable until the runtime confirms it.
          supportsVision: false,
        ),
    ];
  } catch (_) {
    return const [];
  }
}

Future<List<UnifiedModel>> _discoverRemoteModels(
  RemoteProviderConfig config,
  Duration timeout,
) async {
  try {
    final remoteModels = await OpenAiCompatibleInferenceService(config)
        .listModels()
        .timeout(timeout);
    return [
      for (final model in remoteModels)
        if (model.id.endsWith(Uri.encodeComponent(config.modelId)))
          UnifiedModel(
            id: model.id,
            name: model.name,
            isLocal: false,
            size: 0,
            backend: 'remote',
            supportsVision: config.supportsVision,
          ),
    ];
  } catch (_) {
    // Unreachable or policy-blocked providers are not selectable.
    return const [];
  }
}
