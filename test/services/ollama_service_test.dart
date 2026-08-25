import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pocketllm_lite/services/ollama_service.dart';

class MockClient extends http.BaseClient {
  final Future<http.StreamedResponse> Function(http.BaseRequest request)
      _handler;

  MockClient(this._handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _handler(request);
  }
}

void main() {
  group('OllamaService Tests', () {
    test('generateChatStream prepends system prompt correctly', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/chat') {
          if (request is http.Request) {
            final body = jsonDecode(request.body);
            final messages = body['messages'] as List;

            // Check if system prompt is first
            if (messages.isEmpty || messages[0]['role'] != 'system') {
              return http.StreamedResponse(
                Stream.value(utf8.encode('Error: System prompt missing')),
                400,
              );
            }
            if (messages[0]['content'] != 'You are a helpful assistant.') {
              return http.StreamedResponse(
                Stream.value(utf8.encode('Error: Wrong system prompt')),
                400,
              );
            }

            return http.StreamedResponse(
              Stream.value(
                utf8.encode(
                  '{"message": {"content": "Hello"}, "done": false}\n{"done": true}',
                ),
              ),
              200,
            );
          }
        }
        return http.StreamedResponse(Stream.empty(), 404);
      });

      final service = OllamaService(client: mockClient);

      final messages = [
        {'role': 'user', 'content': 'Hi'},
      ];

      final stream = service.generateChatStream(
        'llama3',
        messages,
        system: 'You are a helpful assistant.',
      );

      final result = await stream.join();
      expect(result, 'Hello');
    });

    test('generateChatStream includes options (temperature, top_p)', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/chat') {
          final body = jsonDecode((request as http.Request).body);
          final options = body['options'];

          if (options != null) {
            // print('Received options: $options');
          }

          if (options['temperature'] == 0.7 && options['top_p'] == 0.9) {
            return http.StreamedResponse(
              Stream.value(
                utf8.encode(
                  '{"message": {"content": "OK"}, "done": false}\n{"done": true}',
                ),
              ),
              200,
            );
          }
          return http.StreamedResponse(
            Stream.value(utf8.encode('Error: Options mismatch')),
            400,
          );
        }
        return http.StreamedResponse(Stream.empty(), 404);
      });

      final service = OllamaService(client: mockClient);

      final messages = [
        {'role': 'user', 'content': 'Hi'},
      ];
      final options = {'temperature': 0.7, 'top_p': 0.9};

      final stream = service.generateChatStream(
        'llama3',
        messages,
        options: options,
      );

      final result = await stream.join();
      expect(result, 'OK');
    });

    test('generateChatStream sends correct history', () async {
      final mockClient = MockClient((request) async {
        final body = jsonDecode((request as http.Request).body);
        final messages = body['messages'] as List;

        expect(messages.length, 3);
        expect(messages[0]['role'], 'user');
        expect(messages[0]['content'], 'Hello');
        expect(messages[1]['role'], 'assistant');
        expect(messages[1]['content'], 'Hi there');
        expect(messages[2]['role'], 'user');
        expect(messages[2]['content'], 'How are you?');

        return http.StreamedResponse(
          Stream.value(
            utf8.encode('{"message": {"content": "Good"}, "done": true}'),
          ),
          200,
        );
      });

      final service = OllamaService(client: mockClient);
      final history = [
        {'role': 'user', 'content': 'Hello'},
        {'role': 'assistant', 'content': 'Hi there'},
        {'role': 'user', 'content': 'How are you?'},
      ];

      final stream = service.generateChatStream('llama3', history);
      await stream.join();
    });

    test('embedding uses the official embed endpoint and parses a vector',
        () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/embed');
        final body = jsonDecode((request as http.Request).body);
        expect(body['model'], 'nomic-embed-text');
        expect(body['input'], 'local retrieval');
        expect(body['truncate'], isFalse);
        return http.StreamedResponse(
          Stream.value(utf8.encode('{"embeddings":[[0.1,0.2,0.3]]}')),
          200,
        );
      });

      final service = OllamaService(client: mockClient);
      final vector = await service.generateEmbedding(
        model: 'nomic-embed-text',
        input: 'local retrieval',
      );

      expect(vector, [0.1, 0.2, 0.3]);
    });

    test('stream exposes measured Ollama token counts on the final event',
        () async {
      final mockClient = MockClient((request) async {
        return http.StreamedResponse(
          Stream.value(
            utf8.encode(
              '{"message":{"content":"Hi"},"done":false}\n'
              '{"done":true,"prompt_eval_count":11,"eval_count":3,'
              '"total_duration":250000000}',
            ),
          ),
          200,
        );
      });
      OllamaGenerationStats? stats;
      final service = OllamaService(client: mockClient);

      expect(
        await service
            .generateChatStream(
              'model',
              const [],
              onComplete: (value) => stats = value,
            )
            .join(),
        'Hi',
      );
      expect(stats?.promptTokens, 11);
      expect(stats?.completionTokens, 3);
      expect(stats?.totalDuration, const Duration(milliseconds: 250));
    });
  });
}
