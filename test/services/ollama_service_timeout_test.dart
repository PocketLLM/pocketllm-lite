import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pocketllm_lite/services/ollama_service.dart';

class MockClient extends http.BaseClient {
  final Stream<List<int>> stream;

  MockClient(this.stream);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(stream, 200);
  }
}

void main() {
  group('OllamaService Timeout Tests', () {
    test('generateChatStream times out when server stalls', () async {
      final controller = StreamController<List<int>>();
      final mockClient = MockClient(controller.stream);
      final service = OllamaService(client: mockClient);

      final messages = [{'role': 'user', 'content': 'Hi'}];
      final stream = service.generateChatStream('model', messages);

      // We expect the first value, then an error.
      // The error is wrapped in Exception('Network error: ...') which contains the TimeoutException string
      expect(
        stream,
        emitsInOrder([
          'Hello',
          emitsError(isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('TimeoutException'),
          )),
        ]),
      );

      // Send first chunk
      controller.add(utf8.encode('{"message": {"content": "Hello"}, "done": false}\n'));

      // Do NOT send anything else.
      // The stream should timeout after 5 seconds (AppConstants.streamTimeout).

      // We need to keep the controller open so the stream doesn't close successfully.
      // The test will finish when `expect` is satisfied (error received).
    }, timeout: const Timeout(Duration(seconds: 15)));
  });
}
