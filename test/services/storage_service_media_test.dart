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

    setUp(() {
      storageService = TestStorageService();
    });

    test('getAllImages extracts images from all sessions', () {
      final now = DateTime.now();
      final sessions = [
        ChatSession(
          id: '1',
          title: 'Chat 1',
          model: 'model1',
          createdAt: now,
          messages: [
            ChatMessage(
              role: 'user',
              content: 'Image 1',
              timestamp: now,
              images: ['base64_1'],
            ),
          ],
        ),
        ChatSession(
          id: '2',
          title: 'Chat 2',
          model: 'model1',
          createdAt: now,
          messages: [
            ChatMessage(
              role: 'user',
              content: 'No Image',
              timestamp: now.subtract(const Duration(minutes: 1)),
            ),
            ChatMessage(
              role: 'assistant',
              content: 'Image 2 & 3',
              timestamp: now.subtract(const Duration(minutes: 2)),
              images: ['base64_2', 'base64_3'],
            ),
          ],
        ),
      ];

      storageService.setMockSessions(sessions);

      final images = storageService.getAllImages();

      expect(images.length, 3);
      // Images should be sorted by timestamp descending
      expect(images[0].imageBase64, 'base64_1');
      expect(images[1].imageBase64, 'base64_2');
      expect(images[2].imageBase64, 'base64_3');

      expect(images[0].chatId, '1');
      expect(images[1].chatId, '2');
    });

    test('getAllImages returns empty list if no images', () {
      final sessions = [
        ChatSession(
          id: '1',
          title: 'Chat 1',
          model: 'model1',
          createdAt: DateTime.now(),
          messages: [
            ChatMessage(
              role: 'user',
              content: 'Text only',
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
