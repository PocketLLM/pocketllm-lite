import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pocketllm_lite/services/generation_pipeline.dart';
import 'package:pocketllm_lite/services/inference_service.dart';
import 'package:pocketllm_lite/services/openai_server_service.dart';

class _ServerInference implements InferenceService {
  @override
  Stream<ChatToken> chatStream(ChatRequest request) async* {
    yield const ChatToken(text: 'pipeline ');
    yield const ChatToken(text: 'answer');
  }

  @override
  Future<InferenceMetrics> getMetrics() async =>
      const InferenceMetrics(promptTokens: 3, completionTokens: 2);
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
      const [0.25, 0.75];
}

void main() {
  late OpenAiServerService server;
  late Uri baseUri;
  const key = 'test-server-key';

  setUp(() async {
    final inference = _ServerInference();
    server = OpenAiServerService(
      pipeline: GenerationPipeline(resolveInference: (_) async => inference),
      listModels: () async => const [
        LLMModel(
          id: 'local-test',
          name: 'Local Test',
          backend: InferenceBackend.local,
          sizeBytes: 1,
          isDownloaded: true,
        ),
      ],
      embed: inference.generateEmbeddings,
    );
    await server.startServer(
      const OpenAiServerConfig(enabled: true, port: 0, apiKey: key),
    );
    baseUri = Uri.parse('http://127.0.0.1:${server.boundPort}');
  });

  tearDown(() => server.stopServer());

  test('rejects unauthenticated requests and lists actual models', () async {
    final rejected = await http.get(baseUri.resolve('/v1/models'));
    expect(rejected.statusCode, 401);

    final accepted = await http.get(
      baseUri.resolve('/v1/models'),
      headers: {'Authorization': 'Bearer $key'},
    );
    expect(accepted.statusCode, 200);
    expect(jsonDecode(accepted.body)['data'][0]['id'], 'local-test');
  });

  test('chat completions and embeddings execute real injected runtimes',
      () async {
    final completion = await http.post(
      baseUri.resolve('/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer $key',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'local-test',
        'messages': [
          {'role': 'user', 'content': 'hello'}
        ],
      }),
    );
    expect(completion.statusCode, 200);
    expect(jsonDecode(completion.body)['choices'][0]['message']['content'],
        'pipeline answer');

    final embedding = await http.post(
      baseUri.resolve('/v1/embeddings'),
      headers: {
        'Authorization': 'Bearer $key',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'model': 'local-test', 'input': 'hello'}),
    );
    expect(embedding.statusCode, 200);
    expect(jsonDecode(embedding.body)['data'][0]['embedding'], [0.25, 0.75]);
  });

  test('streaming emits SSE chunks and a done marker', () async {
    final response = await http.post(
      baseUri.resolve('/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer $key',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'local-test',
        'stream': true,
        'messages': [
          {'role': 'user', 'content': 'hello'}
        ],
      }),
    );
    expect(response.headers['content-type'], contains('text/event-stream'));
    expect(response.body, contains('pipeline '));
    expect(response.body, contains('data: [DONE]'));
  });
}
