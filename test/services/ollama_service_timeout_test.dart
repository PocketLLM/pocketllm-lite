import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pocketllm_lite/services/ollama_service.dart';

class MockHangingClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    // Return a stream that yields nothing and stays open
    final controller = StreamController<List<int>>();
    return http.StreamedResponse(controller.stream, 200);
  }
}

void main() {
  test('generateChatStream throws TimeoutException when stream hangs', () async {
    final client = MockHangingClient();
    // Use a short timeout for testing (e.g. 100ms)
    final service = OllamaService(
      client: client,
      streamTimeout: const Duration(milliseconds: 100),
    );

    final stream = service.generateChatStream('model', []);

    // We expect the stream to emit an error (TimeoutException) eventually.
    // If the fix is not implemented, this will hang until the test framework times out.

    await expectLater(
      stream,
      emitsError(isA<Exception>().having(
        (e) => e.toString(),
        'message',
        contains('TimeoutException'),
      )),
    );
  }, timeout: const Timeout(Duration(seconds: 2)));
}
