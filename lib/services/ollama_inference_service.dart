import '../features/chat/domain/models/ollama_model.dart';
import 'inference_service.dart';
import 'ollama_service.dart';

class OllamaInferenceService implements InferenceService {
  final OllamaService _ollamaService;
  InferenceMetrics _lastMetrics = const InferenceMetrics();

  OllamaInferenceService(this._ollamaService);

  @override
  Future<bool> isAvailable() => _ollamaService.checkConnection();

  @override
  Future<List<LLMModel>> listModels() async {
    final models = await _ollamaService.listModels();
    return models.map(_mapModel).toList();
  }

  @override
  Future<void> loadModel(String modelId, {ProgressCallback? onProgress}) async {
    onProgress?.call(
      const InferenceProgress(progress: 1, status: 'Ollama model ready'),
    );
  }

  @override
  Future<void> unloadModel(String modelId) async {}

  @override
  Stream<ChatToken> chatStream(ChatRequest request) async* {
    final stopwatch = Stopwatch()..start();
    var completionCharacters = 0;

    final stream = _ollamaService.generateChatStream(
      request.modelId,
      request.messages.map((message) => message.toOllamaJson()).toList(),
      system: request.systemPrompt,
      options: {
        'temperature': request.temperature,
        'top_p': request.topP,
        'top_k': request.topK,
      },
    );

    await for (final chunk in stream) {
      completionCharacters += chunk.length;
      yield ChatToken(text: chunk);
    }

    stopwatch.stop();
    final estimatedTokens = (completionCharacters / 4).ceil();
    final seconds = stopwatch.elapsedMilliseconds / 1000;
    final tokensPerSecond = seconds > 0 ? estimatedTokens / seconds : 0.0;
    _lastMetrics = InferenceMetrics(
      tokensPerSecond: tokensPerSecond,
      millisecondsPerToken: estimatedTokens > 0
          ? stopwatch.elapsedMilliseconds / estimatedTokens
          : 0,
      totalTime: stopwatch.elapsed,
      completionTokens: estimatedTokens,
    );
  }

  @override
  Future<List<double>> generateEmbeddings(String text, String modelId) {
    throw const InferenceError(
      'Ollama embedding generation is not wired yet for this app version.',
    );
  }

  @override
  Future<InferenceMetrics> getMetrics() async => _lastMetrics;

  LLMModel _mapModel(OllamaModel model) {
    return LLMModel(
      id: model.name,
      name: model.name,
      backend: InferenceBackend.ollama,
      sizeBytes: model.size,
      isDownloaded: true,
    );
  }
}
