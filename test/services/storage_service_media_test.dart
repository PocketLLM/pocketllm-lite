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
          title: 'Chat 1',
          model: 'llama3',
          messages: [
            ChatMessage(
              role: 'user',
              content: 'Image 1',
              timestamp: now.subtract(const Duration(minutes: 5)),
              images: ['base64_1'],
            ),
          ],
          createdAt: now,
        ),
        ChatSession(
          id: '2',
          title: 'Chat 2',
          model: 'mistral',
          messages: [
            ChatMessage(
              role: 'user',
              content: 'No Image',
              timestamp: now.subtract(const Duration(minutes: 10)),
            ),
            ChatMessage(
              role: 'assistant',
              content: 'Image 2 & 3',
              timestamp: now,
              images: ['base64_2', 'base64_3'],
            ),
          ],
          createdAt: now,
        ),
      ];

      storageService.setMockSessions(sessions);
    });

    test('getAllImages returns correct images', () {
      final images = storageService.getAllImages();

      expect(images.length, 3);

      final contents = images.map((i) => i.base64Content).toSet();
      expect(contents.contains('base64_1'), true);
      expect(contents.contains('base64_2'), true);
      expect(contents.contains('base64_3'), true);

      // Check Metadata
      final img1 = images.firstWhere((i) => i.base64Content == 'base64_1');
      expect(img1.chatId, '1');
      expect(img1.chatTitle, 'Chat 1');
    });

    test('getAllImages handles empty sessions', () {
      storageService.setMockSessions([]);
      final images = storageService.getAllImages();
      expect(images.isEmpty, true);
    });
  });
}
