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
  group('StorageService Media Tests', () {
    test('getAllImages returns sorted media items', () {
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
            timestamp: now.subtract(const Duration(hours: 5)),
            images: ['img1_base64'],
          ),
          ChatMessage(
            role: 'assistant',
            content: 'Hi',
            timestamp: now.subtract(const Duration(hours: 4)),
          ),
        ],
      );

      final session2 = ChatSession(
        id: 's2',
        title: 'Session 2',
        model: 'llava',
        createdAt: now,
        messages: [
          ChatMessage(
            role: 'user',
            content: 'Look at this',
            timestamp: now.subtract(const Duration(hours: 1)),
            images: ['img2_base64', 'img3_base64'],
          ),
        ],
      );

      final service = TestStorageService([session1, session2]);
      final images = service.getAllImages();

      expect(images.length, 3);

      // Sort order: Descending by timestamp
      // img2 & img3 (now - 1h) > img1 (now - 5h)

      expect(images[0].chatId, 's2');
      expect(images[0].base64Content, 'img2_base64');

      expect(images[1].chatId, 's2');
      expect(images[1].base64Content, 'img3_base64');

      expect(images[2].chatId, 's1');
      expect(images[2].base64Content, 'img1_base64');
    });

    test('getAllImages returns empty list if no images', () {
       final session1 = ChatSession(
        id: 's1',
        title: 'Session 1',
        model: 'llama3',
        createdAt: DateTime.now(),
        messages: [
          ChatMessage(
            role: 'user',
            content: 'Hello',
            timestamp: DateTime.now(),
          ),
        ],
      );

      final service = TestStorageService([session1]);
      final images = service.getAllImages();

      expect(images, isEmpty);
    });
  });
}
