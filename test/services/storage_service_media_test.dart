import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_session.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_message.dart';
import 'package:pocketllm_lite/features/media/domain/models/media_item.dart';
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
              timestamp: now,
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
              role: 'assistant',
              content: 'No image',
              timestamp: now.subtract(const Duration(minutes: 5)),
            ),
            ChatMessage(
              role: 'user',
              content: 'Image 2 and 3',
              timestamp: now.subtract(const Duration(minutes: 10)),
              images: ['base64_2', 'base64_3'],
            ),
          ],
          createdAt: now.subtract(const Duration(hours: 1)),
        ),
      ];

      storageService.setMockSessions(sessions);
    });

    test('getAllImages returns all images sorted by timestamp desc', () {
      final images = storageService.getAllImages();

      expect(images.length, 3);

      // Image 1 is newest (now)
      expect(images[0].base64, 'base64_1');
      expect(images[0].chatId, '1');

      // Image 2 and 3 are present
      expect(images.any((i) => i.base64 == 'base64_2'), true);
      expect(images.any((i) => i.base64 == 'base64_3'), true);
    });

    test('getAllImages filters by chatId', () {
      final images = storageService.getAllImages(chatId: '2');
      expect(images.length, 2);
      expect(images.any((i) => i.base64 == 'base64_2'), true);
      expect(images.any((i) => i.base64 == 'base64_3'), true);
      expect(images.any((i) => i.base64 == 'base64_1'), false);
    });

    test('MediaItem equality', () {
      final time = DateTime(2024);
      final item1 = MediaItem(chatId: '1', chatTitle: 'Title', timestamp: time, base64: 'abc');
      final item2 = MediaItem(chatId: '1', chatTitle: 'Title', timestamp: time, base64: 'abc');
      final item3 = MediaItem(chatId: '2', chatTitle: 'Title', timestamp: time, base64: 'abc');

      expect(item1, item2);
      expect(item1.hashCode, item2.hashCode);
      expect(item1 == item3, false);
    });
  });
}
