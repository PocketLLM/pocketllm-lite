import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/services/generation_pipeline.dart';
import 'package:pocketllm_lite/services/inference_service.dart';

class _FakeInference implements InferenceService {
  ChatRequest? received;

  @override
  Stream<ChatToken> chatStream(ChatRequest request) async* {
    received = request;
    yield const ChatToken(text: 'real ');
    yield const ChatToken(text: 'output');
  }

  @override
  Future<InferenceMetrics> getMetrics() async => const InferenceMetrics(
        completionTokens: 2,
      );

  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<List<LLMModel>> listModels() async => const [];
  @override
  Future<void> loadModel(String modelId,
      {ProgressCallback? onProgress}) async {}
  @override
  Future<void> unloadModel(String modelId) async {}
  @override
  Future<List<double>> generateEmbeddings(String text, String modelId) async =>
      const [1, 0];
}

void main() {
  test('complete resolves a backend, streams it, and reports measured output',
      () async {
    final backend = _FakeInference();
    final pipeline = GenerationPipeline(
      resolveInference: (_) async => backend,
    );
    const request = ChatRequest(
      modelId: 'verified-model',
      messages: [ChatRequestMessage(role: 'user', content: 'hello')],
    );

    final result = await pipeline.complete(request);

    expect(result.text, 'real output');
    expect(result.metrics.completionTokens, 2);
    expect(backend.received?.modelId, 'verified-model');
  });
}
