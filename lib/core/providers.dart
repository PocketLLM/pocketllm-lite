import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/error_log_service.dart';
import '../services/inference_service_factory.dart';
import '../services/inference_service.dart';
import '../services/ollama_service.dart';
import '../services/storage_service.dart';
import '../services/huggingface_service.dart';
import '../services/tool_calling_service.dart';
import '../services/generation_pipeline.dart';
import '../services/storage_rolling_summary_repository.dart';
import '../services/remote_provider_registry.dart';
import '../services/openai_server_service.dart';
import '../services/openai_compatible_inference_service.dart';
import '../services/app_secret_service.dart';
import '../services/device_tool_action_service.dart';
import 'constants/app_constants.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  throw UnimplementedError('StorageService must be initialized in main.dart');
});

final appSecretServiceProvider = Provider<AppSecretService>((ref) {
  return const AppSecretService();
});

final ollamaServiceProvider = Provider<OllamaService>((ref) {
  final storage = ref.watch(storageServiceProvider);
  final savedUrl = storage.getSetting(
    AppConstants.ollamaBaseUrlKey,
    defaultValue: AppConstants.defaultOllamaBaseUrl,
  );
  return OllamaService(
    baseUrl: savedUrl is String ? savedUrl : AppConstants.defaultOllamaBaseUrl,
  );
});

final errorLogServiceProvider = Provider<ErrorLogService>((ref) {
  throw UnimplementedError('ErrorLogService must be initialized in main.dart');
});

final remoteProviderRegistryProvider = Provider<RemoteProviderRegistry>((ref) {
  return const RemoteProviderRegistry();
});

final inferenceServiceFactoryProvider = Provider<InferenceServiceFactory>((
  ref,
) {
  return InferenceServiceFactory(
    ollamaService: ref.watch(ollamaServiceProvider),
    errorLogService: ref.watch(errorLogServiceProvider),
    remoteProviderRegistry: ref.watch(remoteProviderRegistryProvider),
  );
});

final huggingFaceServiceProvider = Provider<HuggingFaceService>((ref) {
  return HuggingFaceService();
});

final toolCallingServiceProvider = Provider<ToolCallingService>((ref) {
  return ToolCallingService(
    secrets: ref.watch(appSecretServiceProvider),
    deviceActions: PlatformDeviceToolActionService(
      storage: ref.watch(storageServiceProvider),
    ),
  );
});

final generationPipelineProvider = Provider<GenerationPipeline>((ref) {
  return GenerationPipeline(
    inferenceFactory: ref.watch(inferenceServiceFactoryProvider),
    toolService: ref.watch(toolCallingServiceProvider),
    summaryRepository: StorageRollingSummaryRepository(
      ref.watch(storageServiceProvider),
    ),
  );
});

final openAiServerServiceProvider = Provider<OpenAiServerService>((ref) {
  final factory = ref.watch(inferenceServiceFactoryProvider);
  final remoteRegistry = ref.watch(remoteProviderRegistryProvider);
  final service = OpenAiServerService(
    pipeline: ref.watch(generationPipelineProvider),
    listModels: () async {
      final models = <LLMModel>[];
      try {
        models.addAll(await factory.local().listModels());
      } catch (_) {}
      try {
        models.addAll(await factory.ollama().listModels());
      } catch (_) {}
      for (final config in await remoteRegistry.load()) {
        try {
          models.addAll(
            await OpenAiCompatibleInferenceService(config).listModels(),
          );
        } catch (_) {}
      }
      return models;
    },
    embed: (text, modelId) async {
      final service = await factory.chooseForModel(modelId);
      return service.generateEmbeddings(text, modelId);
    },
  );
  ref.onDispose(service.stopServer);
  return service;
});

// Re-export RAG providers from rag_service.dart
// (They are defined in rag_service.dart and embedding_service.dart)
