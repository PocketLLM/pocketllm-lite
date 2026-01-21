import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pocketllm_lite/features/chat/domain/models/pull_progress.dart';
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
  group('OllamaService Pull Streaming Tests', () {
    test('pullModel handles split JSON chunks correctly', () async {
      final controller = StreamController<List<int>>();
      final mockClient = MockClient(controller.stream);
      final service = OllamaService(client: mockClient);

      final stream = service.pullModel('llama3');

      final collectedEvents = <PullProgress>[];
      final subscription = stream.listen((data) {
        collectedEvents.add(data);
      });

      // Split the JSON across two chunks
      // {"status": "downloading", "completed": 100, "total": 1000}
      final part1 = '{"status": "downloading", "comp';
      final part2 = 'leted": 100, "total": 1000}\n';

      controller.add(utf8.encode(part1));
      await Future.delayed(const Duration(milliseconds: 10));
      controller.add(utf8.encode(part2));

      // Add another complete line to ensure stream continues
      final part3 = '{"status": "done"}\n';
      controller.add(utf8.encode(part3));

      await Future.delayed(const Duration(milliseconds: 10));
      await controller.close();
      await subscription.cancel();

      expect(collectedEvents.length, 2);
      expect(collectedEvents[0].status, 'downloading');
      expect(collectedEvents[0].completed, 100);
      expect(collectedEvents[1].status, 'done');
    });
  });
}
