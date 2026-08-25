import 'error_log_service.dart';
import 'inference_service.dart';
import 'local_inference_service.dart';
import 'ollama_inference_service.dart';
import 'ollama_service.dart';
import 'openai_compatible_inference_service.dart';
import 'remote_provider_registry.dart';

class InferenceServiceFactory {
  final OllamaService ollamaService;
  final ErrorLogService errorLogService;
  final RemoteProviderRegistry remoteProviderRegistry;
  LocalInferenceService? _localService;
  OllamaInferenceService? _ollamaInferenceService;
  final Map<String, OpenAiCompatibleInferenceService> _remoteServices = {};

  InferenceServiceFactory({
    required this.ollamaService,
    required this.errorLogService,
    RemoteProviderRegistry? remoteProviderRegistry,
  }) : remoteProviderRegistry =
            remoteProviderRegistry ?? const RemoteProviderRegistry();

  InferenceService local() {
    return _localService ??= LocalInferenceService(
      errorLogService: errorLogService,
    );
  }

  InferenceService ollama() {
    return _ollamaInferenceService ??= OllamaInferenceService(ollamaService);
  }

  Future<InferenceService> chooseForModel(String modelId) async {
    final remote = RemoteProviderConfig.decodeSelection(modelId);
    if (remote != null) {
      final config = await remoteProviderRegistry.find(remote.providerId);
      if (config == null) {
        throw InferenceError(
          'Remote provider "${remote.providerId}" is not configured.',
        );
      }
      return _remoteServices.putIfAbsent(
        config.id,
        () => OpenAiCompatibleInferenceService(config),
      );
    }
    final localService = local();
    late final List<LLMModel> localModels;
    try {
      localModels = await localService.listModels();
    } catch (error) {
      throw InferenceError(
        'Local model discovery failed. PocketLLM did not switch runtimes '
        'silently.',
        error,
      );
    }
    final localMatch = localModels.any(
      (model) => model.id == modelId && model.isDownloaded,
    );
    if (localMatch) return localService;

    final ollamaService = ollama();
    if (await ollamaService.isAvailable()) return ollamaService;

    throw const InferenceError(
      'No inference backend is available. Download a local model or start Ollama.',
    );
  }
}
