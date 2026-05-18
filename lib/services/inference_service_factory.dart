import 'error_log_service.dart';
import 'inference_service.dart';
import 'local_inference_service.dart';
import 'ollama_inference_service.dart';
import 'ollama_service.dart';

class InferenceServiceFactory {
  final OllamaService ollamaService;
  final ErrorLogService errorLogService;
  LocalInferenceService? _localService;
  OllamaInferenceService? _ollamaInferenceService;

  InferenceServiceFactory({
    required this.ollamaService,
    required this.errorLogService,
  });

  InferenceService local() {
    return _localService ??= LocalInferenceService(
      errorLogService: errorLogService,
    );
  }

  InferenceService ollama() {
    return _ollamaInferenceService ??= OllamaInferenceService(ollamaService);
  }

  Future<InferenceService> chooseForModel(String modelId) async {
    final localService = local();
    try {
      final localModels = await localService.listModels();
      final localMatch = localModels.any(
        (model) => model.id == modelId && model.isDownloaded,
      );
      if (localMatch) return localService;
    } catch (_) {
      // The caller still gets an Ollama fallback below.
    }

    final ollamaService = ollama();
    if (await ollamaService.isAvailable()) return ollamaService;

    throw const InferenceError(
      'No inference backend is available. Download a local model or start Ollama.',
    );
  }
}
