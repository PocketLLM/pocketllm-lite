import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_message.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_session.dart';
import 'package:pocketllm_lite/features/media/domain/models/media_item.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

class TestStorageService extends StorageService {
  final List<ChatSession> mockSessions;

  TestStorageService(this.mockSessions);

  @override
  List<ChatSession> getChatSessions() {
    return mockSessions;
  }
}

void main() {
  group('StorageService Media Gallery', () {
    test('getAllImages aggregates images from all sessions and sorts by timestamp descending', () {
      // Setup mock data
      final now = DateTime.now();
      final session1 = ChatSession(
        id: 's1',
        title: 'Session 1',
        model: 'llama3',
        createdAt: now.subtract(const Duration(days: 1)),
        messages: [
          ChatMessage(
            role: 'user',
            content: 'Hello',
            timestamp: now.subtract(const Duration(minutes: 10)),
            images: ['image1'],
          ),
          ChatMessage(
            role: 'assistant',
            content: 'Hi',
            timestamp: now.subtract(const Duration(minutes: 9)),
          ),
        ],
      );

      final session2 = ChatSession(
        id: 's2',
        title: 'Session 2',
        model: 'llama3',
        createdAt: now,
        messages: [
          ChatMessage(
            role: 'user',
            content: 'Look at this',
            timestamp: now,
            images: ['image2', 'image3'],
          ),
        ],
      );

      final service = TestStorageService([session1, session2]);

      // Execute
      final images = service.getAllImages();

      // Verify
      expect(images.length, 3);

      // Check content presence
      expect(images.any((i) => i.base64Content == 'image1'), true);
      expect(images.any((i) => i.base64Content == 'image2'), true);
      expect(images.any((i) => i.base64Content == 'image3'), true);

      // Check sorting (image2 is newer than image1)
      final index1 = images.indexWhere((i) => i.base64Content == 'image1');
      final index2 = images.indexWhere((i) => i.base64Content == 'image2');
      expect(index2 < index1, true); // Newer should be first

      // Check ID format and metadata
      final item1 = images.firstWhere((i) => i.base64Content == 'image1');
      expect(item1.sessionId, 's1');
      expect(item1.sessionTitle, 'Session 1');
      expect(item1.id.startsWith('s1_'), true);
    });

    test('getAllImages handles empty sessions', () {
      final service = TestStorageService([]);
      expect(service.getAllImages(), isEmpty);
    });

    test('getAllImages handles messages without images', () {
       final session = ChatSession(
        id: 's1',
        title: 'Session 1',
        model: 'llama3',
        createdAt: DateTime.now(),
        messages: [
          ChatMessage(
            role: 'user',
            content: 'Hello',
            timestamp: DateTime.now(),
            images: null,
          ),
        ],
      );
      final service = TestStorageService([session]);
      expect(service.getAllImages(), isEmpty);
    });
  });
}
