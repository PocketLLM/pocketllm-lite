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
  group('OllamaService Security Tests', () {
    test('updateBaseUrl throws ArgumentError for invalid schemes', () {
      final service = OllamaService(client: MockClient((_) async => http.StreamedResponse(Stream.empty(), 200)));

      expect(
        () => service.updateBaseUrl('ftp://example.com'),
        throwsArgumentError,
      );
      expect(
        () => service.updateBaseUrl('file:///etc/passwd'),
        throwsArgumentError,
      );
      expect(
        () => service.updateBaseUrl('javascript:alert(1)'),
        throwsArgumentError,
      );
    });

    test('updateBaseUrl throws ArgumentError for non-url strings', () {
      final service = OllamaService(client: MockClient((_) async => http.StreamedResponse(Stream.empty(), 200)));

      expect(
        () => service.updateBaseUrl('not a url'),
        throwsArgumentError,
      );
    });

    test('updateBaseUrl accepts valid http/https urls', () {
      final service = OllamaService(client: MockClient((_) async => http.StreamedResponse(Stream.empty(), 200)));

      expect(
        () => service.updateBaseUrl('http://localhost:11434'),
        returnsNormally,
      );
      expect(
        () => service.updateBaseUrl('https://example.com'),
        returnsNormally,
      );
    });
  });
}
