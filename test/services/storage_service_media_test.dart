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
  group('StorageService Media Gallery', () {
    late TestStorageService storageService;

    setUp(() {
      storageService = TestStorageService();
    });

    test('getAllImages extracts images from sessions', () {
      final now = DateTime.now();
      final sessions = [
        ChatSession(
          id: '1',
          title: 'Chat 1',
          model: 'llama3',
          createdAt: now,
          messages: [
            ChatMessage(
              role: 'user',
              content: 'Look at this',
              timestamp: now,
              images: ['base64_A', 'base64_B'],
            ),
          ],
        ),
        ChatSession(
          id: '2',
          title: 'Chat 2',
          model: 'mistral',
          createdAt: now.subtract(const Duration(hours: 1)),
          messages: [
            ChatMessage(
              role: 'assistant',
              content: 'Here is an image',
              timestamp: now.subtract(const Duration(hours: 1)),
              images: ['base64_C'],
            ),
             ChatMessage(
              role: 'user',
              content: 'Text only',
              timestamp: now,
            ),
          ],
        ),
      ];

      storageService.setMockSessions(sessions);

      final images = storageService.getAllImages();

      expect(images.length, 3);

      // Sorted by timestamp desc (newest first)
      // Image A & B are at 'now'. Image C is at 'now - 1h'.
      // So A/B should be first.

      expect(images[0].base64, anyOf('base64_A', 'base64_B'));
      expect(images[1].base64, anyOf('base64_A', 'base64_B'));
      expect(images[2].base64, 'base64_C');

      expect(images[0].chatId, '1');
      expect(images[2].chatId, '2');
    });

    test('getAllImages returns empty list when no images', () {
      final sessions = [
        ChatSession(
          id: '1',
          title: 'Chat 1',
          model: 'llama3',
          createdAt: DateTime.now(),
          messages: [
            ChatMessage(
              role: 'user',
              content: 'Just text',
              timestamp: DateTime.now(),
            ),
          ],
        ),
      ];
      storageService.setMockSessions(sessions);
      final images = storageService.getAllImages();
      expect(images.isEmpty, true);
    });
  });
}
