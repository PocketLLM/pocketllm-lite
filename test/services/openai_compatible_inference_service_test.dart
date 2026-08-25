import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pocketllm_lite/services/inference_service.dart';
import 'package:pocketllm_lite/services/network_gateway.dart';
import 'package:pocketllm_lite/services/openai_compatible_inference_service.dart';
import 'package:pocketllm_lite/services/remote_provider_registry.dart';

void main() {
  const config = RemoteProviderConfig(
    id: 'local-studio',
    name: 'Local Studio',
    baseUrl: 'http://127.0.0.1:1234',
    apiKey: 'test-key',
    modelId: 'verified-model',
  );

  test('lists models, streams chat, and creates embeddings through gateway',
      () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path == '/v1/models') {
        return http.Response(
          jsonEncode({
            'data': [
              {'id': 'verified-model'}
            ],
          }),
          200,
        );
      }
      if (request.url.path == '/v1/chat/completions') {
        return http.Response(
          'data: ${jsonEncode({
                'choices': [
                  {
                    'delta': {'content': 'real '}
                  }
                ]
              })}\n\n'
          'data: ${jsonEncode({
                'choices': [
                  {
                    'delta': {'content': 'stream'}
                  }
                ],
                'usage': {'prompt_tokens': 3, 'completion_tokens': 2}
              })}\n\n'
          'data: [DONE]\n\n',
          200,
          headers: {'content-type': 'text/event-stream'},
        );
      }
      if (request.url.path == '/v1/embeddings') {
        return http.Response(
          jsonEncode({
            'data': [
              {
                'embedding': [0.25, 0.75]
              }
            ],
          }),
          200,
        );
      }
      return http.Response('not found', 404);
    });
    final service = OpenAiCompatibleInferenceService(
      config,
      network: NetworkGateway(client: client),
    );

    final models = await service.listModels();
    final output = await service
        .chatStream(
          const ChatRequest(
            modelId: 'remote::local-studio::verified-model',
            messages: [
              ChatRequestMessage(role: 'user', content: 'hello'),
            ],
          ),
        )
        .map((token) => token.text)
        .join();
    final embedding = await service.generateEmbeddings(
      'hello',
      'remote::local-studio::verified-model',
    );

    expect(models.single.backend, InferenceBackend.remote);
    expect(output, 'real stream');
    expect(embedding, [0.25, 0.75]);
    expect(
        requests.every(
            (request) => request.headers['authorization'] == 'Bearer test-key'),
        isTrue);
    expect((await service.getMetrics()).tokenCountsEstimated, isFalse);
  });

  test('rejects custom authorization and host header overrides', () {
    expect(
      () => OpenAiCompatibleInferenceService(
        const RemoteProviderConfig(
          id: 'bad',
          name: 'Bad',
          baseUrl: 'https://example.com',
          modelId: 'model',
          customHeaders: {'Authorization': 'untrusted'},
        ),
      ),
      throwsA(isA<RemoteProviderError>()),
    );
  });
}
