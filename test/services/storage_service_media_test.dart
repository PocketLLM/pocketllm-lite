import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_message.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_session.dart';
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
  group('StorageService - Media Gallery', () {
    test('getAllImages returns aggregated images sorted by timestamp', () {
      final now = DateTime.now();

      final session1 = ChatSession(
        id: 'chat1',
        title: 'Chat 1',
        model: 'llama3',
        createdAt: now.subtract(const Duration(hours: 2)),
        messages: [
          ChatMessage(
            role: 'user',
            content: 'Image 1',
            timestamp: now.subtract(const Duration(minutes: 50)),
            images: ['base64_img1'],
          ),
          ChatMessage(
            role: 'assistant',
            content: 'Response',
            timestamp: now.subtract(const Duration(minutes: 49)),
          ),
        ],
      );

      final session2 = ChatSession(
        id: 'chat2',
        title: 'Chat 2',
        model: 'llama3',
        createdAt: now.subtract(const Duration(hours: 1)),
        messages: [
          ChatMessage(
            role: 'user',
            content: 'Image 2 and 3',
            timestamp: now.subtract(const Duration(minutes: 10)),
            images: ['base64_img2', 'base64_img3'],
          ),
        ],
      );

      final service = TestStorageService([session1, session2]);
      final images = service.getAllImages();

      expect(images.length, 3);

      // Expected order: Newest first
      // img2 and img3 are at now-10min.
      // img1 is at now-50min.

      expect(images[0].base64Content, 'base64_img2');
      expect(images[0].chatId, 'chat2');

      expect(images[1].base64Content, 'base64_img3');
      expect(images[1].chatId, 'chat2');

      expect(images[2].base64Content, 'base64_img1');
      expect(images[2].chatId, 'chat1');
    });

    test('getAllImages returns empty list if no images', () {
       final session = ChatSession(
        id: 'chat1',
        title: 'Chat 1',
        model: 'llama3',
        createdAt: DateTime.now(),
        messages: [
          ChatMessage(
            role: 'user',
            content: 'No images',
            timestamp: DateTime.now(),
          ),
        ],
      );

      final service = TestStorageService([session]);
      final images = service.getAllImages();

      expect(images, isEmpty);
    });
  });
}
