import 'package:cactus/cactus.dart' as cactus;

import 'error_log_service.dart';
import 'inference_service.dart';

class LocalInferenceService implements InferenceService {
  final cactus.CactusLM _lm;
  final ErrorLogService? _errorLogService;
  final int contextSize;
  String? _loadedModelId;
  InferenceMetrics _lastMetrics = const InferenceMetrics();

  LocalInferenceService({
    cactus.CactusLM? lm,
    ErrorLogService? errorLogService,
    this.contextSize = 2048,
  }) : _lm = lm ?? cactus.CactusLM(),
       _errorLogService = errorLogService;

  @override
  Future<bool> isAvailable() async {
    try {
      await _lm.getModels();
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<LLMModel>> listModels() async {
    try {
      final models = await _lm.getModels();
      return models
          .map(
            (model) => LLMModel(
              id: model.slug,
              name: model.name,
              backend: InferenceBackend.local,
              sizeBytes: model.sizeMb * 1024 * 1024,
              isDownloaded: model.isDownloaded,
              supportsVision: model.supportsVision,
              supportsToolCalling: model.supportsToolCalling,
              quantizationBits: model.quantization,
            ),
          )
          .toList();
    } catch (error, stackTrace) {
      await _logLocalError(error, stackTrace, 'Failed to list local models');
      throw InferenceError('Failed to list local Cactus models.', error);
    }
  }

  @override
  Future<void> loadModel(String modelId, {ProgressCallback? onProgress}) async {
    try {
      if (_loadedModelId == modelId && _lm.isLoaded()) {
        onProgress?.call(
          const InferenceProgress(progress: 1, status: 'Model already loaded'),
        );
        return;
      }

      if (_lm.isLoaded()) {
        _lm.unload();
      }

      await _lm.downloadModel(
        model: modelId,
        downloadProcessCallback: (progress, status, isError) {
          onProgress?.call(
            InferenceProgress(
              progress: progress,
              status: status,
              isError: isError,
            ),
          );
        },
      );
      onProgress?.call(
        const InferenceProgress(progress: 0.95, status: 'Initializing model'),
      );
      await _lm.initializeModel(
        params: cactus.CactusInitParams(
          model: modelId,
          contextSize: contextSize,
        ),
      );
      _loadedModelId = modelId;
      onProgress?.call(
        const InferenceProgress(progress: 1, status: 'Model loaded'),
      );
    } catch (error, stackTrace) {
      await _logLocalError(error, stackTrace, 'Failed to load local model');
      throw InferenceError('Failed to load local model "$modelId".', error);
    }
  }

  @override
  Future<void> unloadModel(String modelId) async {
    if (_loadedModelId == modelId && _lm.isLoaded()) {
      _lm.unload();
      _loadedModelId = null;
    }
  }

  @override
  Stream<ChatToken> chatStream(ChatRequest request) async* {
    await loadModel(request.modelId);

    try {
      final messages = <cactus.ChatMessage>[
        if (request.systemPrompt?.isNotEmpty ?? false)
          cactus.ChatMessage(content: request.systemPrompt!, role: 'system'),
        ...request.messages.map(
          (message) => cactus.ChatMessage(
            content: message.content,
            role: message.role,
            images: message.images ?? const [],
          ),
        ),
      ];

      final streamed = await _lm.generateCompletionStream(
        messages: messages,
        params: cactus.CactusCompletionParams(
          model: request.modelId,
          temperature: request.temperature,
          topK: request.topK,
          topP: request.topP,
          maxTokens: request.maxTokens,
        ),
      );

      await for (final chunk in streamed.stream) {
        yield ChatToken(text: chunk);
      }

      final result = await streamed.result;
      _lastMetrics = InferenceMetrics(
        tokensPerSecond: result.tokensPerSecond,
        millisecondsPerToken: result.tokensPerSecond > 0
            ? 1000 / result.tokensPerSecond
            : 0,
        totalTime: Duration(milliseconds: result.totalTimeMs.round()),
        promptTokens: result.prefillTokens,
        completionTokens: result.decodeTokens,
      );

      if (!result.success) {
        throw const InferenceError(
          'Local model returned an unsuccessful result.',
        );
      }
    } catch (error, stackTrace) {
      await _logLocalError(error, stackTrace, 'Local inference failed');
      throw InferenceError('Local inference failed.', error);
    }
  }

  @override
  Future<List<double>> generateEmbeddings(String text, String modelId) async {
    await loadModel(modelId);
    final result = await _lm.generateEmbedding(text: text, modelName: modelId);
    if (!result.success) {
      throw InferenceError(
        result.errorMessage ?? 'Embedding generation failed.',
      );
    }
    return result.embeddings;
  }

  @override
  Future<InferenceMetrics> getMetrics() async => _lastMetrics;

  Future<void> _logLocalError(
    Object error,
    StackTrace stackTrace,
    String message,
  ) async {
    await _errorLogService?.logError(
      category: ErrorCategory.inference,
      message: message,
      details: error.toString(),
      stackTrace: stackTrace.toString(),
      suggestedFix:
          'Try a smaller quantized model, reduce context length, or restart the app to free memory.',
    );
  }
}
