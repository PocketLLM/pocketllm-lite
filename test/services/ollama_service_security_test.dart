import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pocketllm_lite/services/ollama_service.dart';

class MockClient extends http.BaseClient {
  Uri? lastRequestUrl;
  Object? exceptionToThrow;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    lastRequestUrl = request.url;
    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }
    // Return empty stream 200 OK by default
    return http.StreamedResponse(const Stream.empty(), 200);
  }
}

void main() {
  group('OllamaService Security Tests', () {
    test('updateBaseUrl sanitizes trailing slashes and whitespace', () async {
      final mockClient = MockClient();
      final service = OllamaService(client: mockClient);

      // Set dirty URL
      service.updateBaseUrl(' http://localhost:11434/ ');

      // Trigger a request (e.g. checkConnection uses $_baseUrl/api/tags)
      await service.checkConnection();

      // Expect sanitized URL in request
      expect(
        mockClient.lastRequestUrl.toString(),
        'http://localhost:11434/api/tags',
      );
    });

    test('updateBaseUrl throws ArgumentError for invalid schemes', () {
      final mockClient = MockClient();
      final service = OllamaService(client: mockClient);

      expect(
        () => service.updateBaseUrl('ftp://localhost:11434'),
        throwsArgumentError,
      );

      expect(
        () => service.updateBaseUrl('javascript:alert(1)'),
        throwsArgumentError,
      );
    });

    test('Error messages redact credentials', () async {
      final mockClient = MockClient();
      // Exception with credentials
      mockClient.exceptionToThrow = http.ClientException(
        'Failed to connect to http://user:secret@example.com:11434/api/tags',
      );

      final service = OllamaService(client: mockClient);

      expect(
        () => service.listModels(),
        throwsA(
          predicate((e) {
            final msg = e.toString();
            return msg.contains('http://***@example.com') &&
                !msg.contains('secret');
          }),
        ),
      );
    });
  });
}
