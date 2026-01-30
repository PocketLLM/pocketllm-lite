import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_message.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_session.dart';
import 'package:pocketllm_lite/features/chat/domain/models/media_item.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

class MockStorageService extends StorageService {
  final List<ChatSession> mockSessions;

  MockStorageService(this.mockSessions);

  @override
  List<ChatSession> getChatSessions() {
    return mockSessions;
  }
}

void main() {
  group('StorageService - getAllImages', () {
    test('should return empty list if no images', () {
      final service = MockStorageService([
        ChatSession(
          id: '1',
          title: 'Chat 1',
          model: 'llama3',
          messages: [
            ChatMessage(role: 'user', content: 'Hi', timestamp: DateTime.now()),
          ],
          createdAt: DateTime.now(),
        ),
      ]);

      final images = service.getAllImages();
      expect(images, isEmpty);
    });

    test('should aggregate images from multiple sessions and messages', () {
      final now = DateTime.now();
      final service = MockStorageService([
        ChatSession(
          id: 'chat1',
          title: 'Chat 1',
          model: 'llama3',
          messages: [
            ChatMessage(
              role: 'user',
              content: 'Look',
              timestamp: now.subtract(const Duration(minutes: 10)),
              images: ['base64_A'],
            ),
          ],
          createdAt: now.subtract(const Duration(days: 1)),
        ),
        ChatSession(
          id: 'chat2',
          title: 'Chat 2',
          model: 'llama3',
          messages: [
            ChatMessage(
              role: 'user',
              content: 'Two images',
              timestamp: now,
              images: ['base64_B', 'base64_C'],
            ),
          ],
          createdAt: now,
        ),
      ]);

      final images = service.getAllImages();
      expect(images.length, 3);

      // Verify sorting (newest first)
      // Note: base64_B and base64_C have same timestamp. Order is preservation of iteration order for same timestamp.
      // But we sort by timestamp descending.
      // 'chat2' messages are newer (timestamp: now) than 'chat1' (now - 10 min).

      // The sort is stable if timestamps are equal? Dart sort is stable since 2.0 I think, but let's see.
      // Actually if timestamps are equal, the sort doesn't swap.
      // So 'base64_B' then 'base64_C' (index 0 then 1).

      expect(images[0].base64Image, 'base64_B');
      expect(images[1].base64Image, 'base64_C');
      expect(images[2].base64Image, 'base64_A');

      // Verify properties
      expect(images[0].chatId, 'chat2');
      expect(images[0].index, 0);
      expect(images[1].chatId, 'chat2');
      expect(images[1].index, 1);
      expect(images[2].chatId, 'chat1');
    });
  });
}
