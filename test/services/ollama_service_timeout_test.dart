import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pocketllm_lite/services/ollama_service.dart';

class MockClient extends http.BaseClient {
  final Stream<List<int>> stream;
  final int statusCode;

  MockClient(this.stream, {this.statusCode = 200});

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(stream, statusCode);
  }
}

void main() {
  group('OllamaService Timeout Tests', () {
    test('generateChatStream throws TimeoutException (wrapped in Exception) when stream stalls', () async {
      // Create a stream controller but never add data to it (simulating stall)
      final controller = StreamController<List<int>>();
      final mockClient = MockClient(controller.stream);

      // Use a very short timeout for testing
      final service = OllamaService(
        client: mockClient,
        streamTimeout: const Duration(milliseconds: 50),
      );

      final messages = [{'role': 'user', 'content': 'Hi'}];
      final stream = service.generateChatStream('model', messages);

      // The service wraps errors in Exception('Network error: $e')
      // TimeoutException is rethrown as Network error.
      await expectLater(
        stream,
        emitsError(predicate((e) =>
          e is Exception && e.toString().contains('TimeoutException')
        ))
      );

      await controller.close();
    });

    test('pullModel throws TimeoutException (wrapped in Exception) when stream stalls', () async {
      final controller = StreamController<List<int>>();
      final mockClient = MockClient(controller.stream);

      final service = OllamaService(
        client: mockClient,
        streamTimeout: const Duration(milliseconds: 50),
      );

      final stream = service.pullModel('model');

      await expectLater(
        stream,
        emitsError(predicate((e) =>
          e is Exception && e.toString().contains('TimeoutException')
        ))
      );

      await controller.close();
    });
  });
}
