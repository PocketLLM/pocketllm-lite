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
  group('OllamaService Streaming Tests', () {
    test('generateChatStream handles split JSON chunks correctly', () async {
      // Simulate a stream where a JSON line is split across two chunks
      final controller = StreamController<List<int>>();
      final mockClient = MockClient(controller.stream);
      final service = OllamaService(client: mockClient);

      final messages = [
        {'role': 'user', 'content': 'Hi'},
      ];
      final stream = service.generateChatStream('model', messages);

      final collectedOutput = <String>[];
      final subscription = stream.listen((data) {
        collectedOutput.add(data);
      });

      // Chunk 1: First complete JSON + half of second JSON
      // {"message": {"content": "Hello "}, "done": false}
      // {"message": {"content": "wor
      final chunk1 =
          '{"message": {"content": "Hello "}, "done": false}\n{"message": {"content": "wor';
      controller.add(utf8.encode(chunk1));

      // Wait a bit to ensure processing
      await Future.delayed(Duration(milliseconds: 10));

      // Chunk 2: Rest of second JSON + third complete JSON
      // ld!"}, "done": false}
      // {"done": true}
      final chunk2 = 'ld!"}, "done": false}\n{"done": true}\n';
      controller.add(utf8.encode(chunk2));

      await Future.delayed(Duration(milliseconds: 10));
      await controller.close();
      await subscription.cancel();

      // With split('\n'), the second message "world!" would be corrupted or lost.
      // "wor" would be parsed as JSON -> fail -> ignored.
      // "ld!"... would be parsed as JSON -> fail -> ignored.
      // So we expect only "Hello " to be captured if the bug exists.

      // If optimized with LineSplitter, it should buffer "wor" and combine with "ld!"...
      // producing "Hello " and "world!".

      //print('Collected output: $collectedOutput');

      // This assertion is expected to FAIL with current implementation
      expect(collectedOutput.join(''), 'Hello world!');
    });
  });
}
