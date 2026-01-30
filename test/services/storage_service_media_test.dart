import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_session.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_message.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

class TestStorageService extends StorageService {
  List<ChatSession> _mockSessions = [];

  void setMockSessions(List<ChatSession> sessions) {
    _mockSessions = sessions;
  }

  @override
  List<ChatSession> getChatSessions() {
    return _mockSessions;
  }
}

void main() {
  group('StorageService Media Logic', () {
    late TestStorageService storageService;
    late List<ChatSession> sessions;

    setUp(() {
      storageService = TestStorageService();
      final now = DateTime.now();

      sessions = [
        ChatSession(
          id: '1',
          title: 'Session 1',
          model: 'llama3',
          messages: [
            ChatMessage(
              role: 'user',
              content: 'Image 1',
              timestamp: now.subtract(const Duration(hours: 1)),
              images: ['base64_image_1'],
            ),
            ChatMessage(role: 'assistant', content: 'Response', timestamp: now),
          ],
          createdAt: now.subtract(const Duration(hours: 1)),
        ),
        ChatSession(
          id: '2',
          title: 'Session 2',
          model: 'mistral',
          messages: [
            ChatMessage(
              role: 'user',
              content: 'Image 2 and 3',
              timestamp: now.subtract(const Duration(days: 1)),
              images: ['base64_image_2', 'base64_image_3'],
            ),
          ],
          createdAt: now.subtract(const Duration(days: 1)),
        ),
        ChatSession(
          id: '3',
          title: 'Session 3',
          model: 'llama3',
          messages: [
            ChatMessage(
              role: 'user',
              content: 'No images',
              timestamp: now.subtract(const Duration(days: 2)),
            ),
          ],
          createdAt: now.subtract(const Duration(days: 2)),
        ),
      ];

      storageService.setMockSessions(sessions);
    });

    test('getAllImages returns all images sorted by date (newest first)', () {
      final images = storageService.getAllImages();

      // Total images: 1 (from session 1) + 2 (from session 2) = 3
      expect(images.length, 3);

      // Order should be Newest -> Oldest
      // Session 1 is 1 hour ago.
      // Session 2 is 1 day ago.

      expect(images[0].base64Image, 'base64_image_1');
      expect(images[0].chatId, '1');

      expect(images[1].chatId, '2');
      expect(images[2].chatId, '2');

      expect(images[1].timestamp.isBefore(images[0].timestamp), true);
    });

    test('getAllImages returns empty list if no images', () {
      storageService.setMockSessions([
        ChatSession(
          id: '4',
          title: 'Empty',
          model: 'test',
          messages: [
            ChatMessage(
              role: 'user',
              content: 'test',
              timestamp: DateTime.now(),
            ),
          ],
          createdAt: DateTime.now(),
        ),
      ]);

      final images = storageService.getAllImages();
      expect(images.isEmpty, true);
    });
  });
}
