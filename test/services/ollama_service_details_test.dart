import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pocketllm_lite/services/ollama_service.dart';

class MockClient extends http.BaseClient {
  final Future<http.StreamedResponse> Function(http.BaseRequest request) _handler;

  MockClient(this._handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _handler(request);
  }
}

void main() {
  group('OllamaService getModelDetails Tests', () {
    test('getModelDetails parses successful response correctly', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/show' && request.method == 'POST') {
          final body = jsonDecode((request as http.Request).body);
          if (body['name'] == 'llama3') {
            return http.StreamedResponse(
              Stream.value(utf8.encode(jsonEncode({
                "license": "MIT License",
                "modelfile": "FROM llama3\nPARAMETER temperature 0.7",
                "parameters": "temperature 0.7",
                "template": "{{ .System }} {{ .Prompt }}",
                "details": {
                  "format": "gguf",
                  "family": "llama",
                  "families": ["llama"],
                  "parameter_size": "8B",
                  "quantization_level": "Q4_K_M"
                }
              }))),
              200,
            );
          }
        }
        return http.StreamedResponse(Stream.empty(), 404);
      });

      final service = OllamaService(client: mockClient);
      final details = await service.getModelDetails('llama3');

      expect(details.license, 'MIT License');
      expect(details.details.parameterSize, '8B');
      expect(details.details.quantizationLevel, 'Q4_K_M');
      expect(details.details.families, contains('llama'));
    });

    test('getModelDetails throws exception on 404', () async {
      final mockClient = MockClient((request) async {
        return http.StreamedResponse(
          Stream.value(utf8.encode('Not Found')),
          404,
        );
      });

      final service = OllamaService(client: mockClient);
      expect(
        () => service.getModelDetails('non_existent'),
        throwsException,
      );
    });
  });
}
