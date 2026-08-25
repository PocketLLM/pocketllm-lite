import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/services/generation_pipeline.dart';
import 'package:pocketllm_lite/services/inference_service.dart';
import 'package:pocketllm_lite/services/storage_service.dart';
import 'package:pocketllm_lite/services/tool_calling_service.dart';
import 'package:pocketllm_lite/services/local_memory_service.dart';

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

class _Storage extends StorageService {
  final Map<String, dynamic> values = {};

  @override
  dynamic getSetting(String key, {dynamic defaultValue}) =>
      values[key] ?? defaultValue;

  @override
  Future<void> saveSetting(String key, dynamic value) async {
    values[key] = value;
  }
}

class _MemoryExtractingInference extends _FakeInference {
  @override
  Stream<ChatToken> chatStream(ChatRequest request) async* {
    if (request.systemPrompt?.contains('Extract only durable') == true) {
      yield const ChatToken(
        text: '[{"key":"test_editor","type":"preference",'
            '"subject":"user","fact":"The user prefers Vim.",'
            '"confidence":0.96}]',
      );
      return;
    }
    yield const ChatToken(text: 'Preference noted.');
  }
}

class _ToolLoopInference extends _FakeInference {
  final bool malformed;
  int calls = 0;

  _ToolLoopInference({this.malformed = false});

  @override
  Stream<ChatToken> chatStream(ChatRequest request) async* {
    calls++;
    final hasToolResult = request.messages.any(
      (message) => message.content.contains('tool_call_id'),
    );
    if (hasToolResult) {
      yield const ChatToken(text: 'The calculated answer is 42.');
      return;
    }
    yield ChatToken(
      text: malformed
          ? '{"tool":"calculator","arguments":{"expression":42}}'
          : '{"tool":"calculator","arguments":{"expression":"6 * 7"}}',
    );
  }
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

  test('central pipeline validates, executes, injects, and completes tool loop',
      () async {
    final backend = _ToolLoopInference();
    final events = <GenerationToolEvent>[];
    final pipeline = GenerationPipeline(
      resolveInference: (_) async => backend,
      toolService: ToolCallingService(),
    );
    const request = ChatRequest(
      modelId: 'verified-model',
      messages: [ChatRequestMessage(role: 'user', content: 'What is 6 * 7?')],
    );

    final result = await pipeline.complete(
      request,
      options: GenerationOptions(
        enableTools: true,
        allowedTools: {'calculator'},
        onToolEvent: (event) async => events.add(event),
      ),
    );

    expect(result.text, 'The calculated answer is 42.');
    expect(result.toolResults.single.success, isTrue);
    expect(result.toolResults.single.output, contains('42'));
    expect(events.map((event) => event.type), [
      GenerationToolEventType.call,
      GenerationToolEventType.result,
    ]);
    expect(backend.calls, 2);
  });

  test('malformed tool arguments are rejected without executing the handler',
      () async {
    final backend = _ToolLoopInference(malformed: true);
    final pipeline = GenerationPipeline(
      resolveInference: (_) async => backend,
      toolService: ToolCallingService(),
    );
    const request = ChatRequest(
      modelId: 'verified-model',
      messages: [ChatRequestMessage(role: 'user', content: 'Calculate')],
    );

    final result = await pipeline.complete(
      request,
      options: const GenerationOptions(
        enableTools: true,
        allowedTools: {'calculator'},
      ),
    );

    expect(result.toolResults.single.success, isFalse);
    expect(result.toolResults.single.error, contains('must be a string'));
    expect(result.text, 'The calculated answer is 42.');
  });

  test('opt-in extraction stores validated memory with a real embedding',
      () async {
    final storage = _Storage();
    final memory = LocalMemoryService();
    await memory.init(storage);
    final backend = _MemoryExtractingInference();
    final pipeline = GenerationPipeline(
      resolveInference: (_) async => backend,
      memoryService: memory,
    );

    await pipeline.complete(
      const ChatRequest(
        modelId: 'verified-model',
        messages: [
          ChatRequestMessage(role: 'user', content: 'I prefer Vim.'),
        ],
      ),
      options: const GenerationOptions(enableMemoryExtraction: true),
    );

    final stored = memory
        .getMemories()
        .where((entry) => entry.memoryKey == 'test_editor')
        .single;
    expect(stored.embedding, [1, 0]);
    expect(stored.fact, 'The user prefers Vim.');
  });
}
