typedef ProgressCallback = void Function(InferenceProgress progress);

enum InferenceBackend { local, ollama }

class InferenceProgress {
  final double? progress;
  final String status;
  final bool isError;

  const InferenceProgress({
    required this.status,
    this.progress,
    this.isError = false,
  });
}

class LLMModel {
  final String id;
  final String name;
  final InferenceBackend backend;
  final int? sizeBytes;
  final bool isDownloaded;
  final bool supportsVision;
  final bool supportsToolCalling;
  final int? quantizationBits;

  const LLMModel({
    required this.id,
    required this.name,
    required this.backend,
    this.sizeBytes,
    this.isDownloaded = false,
    this.supportsVision = false,
    this.supportsToolCalling = false,
    this.quantizationBits,
  });
}

class ChatRequestMessage {
  final String role;
  final String content;
  final List<String>? images;

  const ChatRequestMessage({
    required this.role,
    required this.content,
    this.images,
  });

  Map<String, dynamic> toOllamaJson() {
    return {
      'role': role,
      'content': content,
      if (images != null && images!.isNotEmpty) 'images': images,
    };
  }
}

class ChatRequest {
  final String modelId;
  final List<ChatRequestMessage> messages;
  final String? systemPrompt;
  final double temperature;
  final double topP;
  final int topK;
  final int maxTokens;

  const ChatRequest({
    required this.modelId,
    required this.messages,
    this.systemPrompt,
    this.temperature = 0.7,
    this.topP = 0.9,
    this.topK = 40,
    this.maxTokens = 512,
  });
}

class ChatToken {
  final String text;
  final bool isThinking;

  const ChatToken({required this.text, this.isThinking = false});
}

class InferenceMetrics {
  final double tokensPerSecond;
  final double millisecondsPerToken;
  final Duration totalTime;
  final int promptTokens;
  final int completionTokens;

  const InferenceMetrics({
    this.tokensPerSecond = 0,
    this.millisecondsPerToken = 0,
    this.totalTime = Duration.zero,
    this.promptTokens = 0,
    this.completionTokens = 0,
  });
}

abstract class InferenceService {
  Future<bool> isAvailable();
  Future<List<LLMModel>> listModels();
  Future<void> loadModel(String modelId, {ProgressCallback? onProgress});
  Future<void> unloadModel(String modelId);
  Stream<ChatToken> chatStream(ChatRequest request);
  Future<List<double>> generateEmbeddings(String text, String modelId);
  Future<InferenceMetrics> getMetrics();
}

class InferenceException implements Exception {
  final String message;
  final Object? cause;

  const InferenceException(this.message, [this.cause]);

  @override
  String toString() => cause == null ? message : '$message: $cause';
}

class InsufficientMemoryError extends InferenceException {
  const InsufficientMemoryError(super.message, [super.cause]);
}

class ModelCorruptedError extends InferenceException {
  const ModelCorruptedError(super.message, [super.cause]);
}

class InferenceError extends InferenceException {
  const InferenceError(super.message, [super.cause]);
}
