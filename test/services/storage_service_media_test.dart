import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_session.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_message.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

// Subclass to mock getChatSessions
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
  group('StorageService Media Gallery Logic', () {
    late TestStorageService storageService;
    late List<ChatSession> sessions;

    setUp(() {
      storageService = TestStorageService();
      final now = DateTime.now();

      // Mock Base64 images
      const img1 = 'base64_1';
      const img2 = 'base64_2';
      const img3 = 'base64_3';

      sessions = [
        ChatSession(
          id: '1',
          title: 'Chat 1',
          model: 'llama3',
          messages: [
            ChatMessage(
              role: 'user',
              content: 'Image 1',
              timestamp: now.subtract(const Duration(minutes: 5)),
              images: [img1],
            ),
             ChatMessage(
              role: 'assistant',
              content: 'Response',
              timestamp: now.subtract(const Duration(minutes: 4)),
            ),
          ],
          createdAt: now.subtract(const Duration(minutes: 10)),
        ),
        ChatSession(
          id: '2',
          title: 'Chat 2',
          model: 'mistral',
          messages: [
             ChatMessage(
              role: 'user',
              content: 'Image 2 and 3',
              timestamp: now.subtract(const Duration(hours: 1)),
              images: [img2, img3],
            ),
          ],
          createdAt: now.subtract(const Duration(hours: 2)),
        ),
         ChatSession(
          id: '3',
          title: 'Chat 3',
          model: 'gemma',
          messages: [
             ChatMessage(
              role: 'user',
              content: 'No images',
              timestamp: now.subtract(const Duration(days: 1)),
            ),
          ],
          createdAt: now.subtract(const Duration(days: 1)),
        ),
      ];

      storageService.setMockSessions(sessions);
    });

    test('getAllImages returns all images sorted by date desc', () {
      final images = storageService.getAllImages();

      expect(images.length, 3);

      // Order: img1 (5 mins ago), img2 (1 hour ago), img3 (1 hour ago)
      expect(images[0].base64Content, 'base64_1');
      expect(images[1].base64Content, 'base64_2');
      expect(images[2].base64Content, 'base64_3');

      expect(images[0].chatId, '1');
      expect(images[1].chatId, '2');

      // Verify other fields
      expect(images[0].chatTitle, 'Chat 1');
      expect(images[1].chatTitle, 'Chat 2');
    });

    test('getAllImages generates unique IDs', () {
      final images = storageService.getAllImages();
      final ids = images.map((i) => i.id).toSet();
      expect(ids.length, 3);
    });

    test('getAllImages handles empty sessions', () {
      storageService.setMockSessions([]);
      final images = storageService.getAllImages();
      expect(images.isEmpty, true);
    });
  });
}
