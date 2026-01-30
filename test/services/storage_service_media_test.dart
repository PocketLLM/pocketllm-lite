import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_session.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_message.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

// Test subclass to bypass Hive dependency
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

    setUp(() {
      storageService = TestStorageService();
    });

    test('getAllImages returns empty list when no images exist', () {
      storageService.setMockSessions([
        ChatSession(
          id: '1',
          title: 'Text only',
          model: 'llama3',
          messages: [
            ChatMessage(
              role: 'user',
              content: 'Hello',
              timestamp: DateTime.now(),
            ),
          ],
          createdAt: DateTime.now(),
        ),
      ]);

      final images = storageService.getAllImages();
      expect(images.isEmpty, true);
    });

    test('getAllImages aggregates images from multiple chats and messages', () {
      final now = DateTime.now();
      storageService.setMockSessions([
        ChatSession(
          id: '1',
          title: 'Chat with images',
          model: 'llama3-vision',
          messages: [
            ChatMessage(
              role: 'user',
              content: 'Look at this',
              timestamp: now,
              images: ['base64_img_1'],
            ),
            ChatMessage(
              role: 'assistant',
              content: 'Nice',
              timestamp: now.add(const Duration(seconds: 1)),
            ),
            ChatMessage(
              role: 'user',
              content: 'Another one',
              timestamp: now.add(const Duration(seconds: 2)),
              images: ['base64_img_2', 'base64_img_3'],
            ),
          ],
          createdAt: now,
        ),
        ChatSession(
          id: '2',
          title: 'Older chat with image',
          model: 'llava',
          messages: [
            ChatMessage(
              role: 'user',
              content: 'Old image',
              timestamp: now.subtract(const Duration(days: 1)),
              images: ['base64_img_old'],
            ),
          ],
          createdAt: now.subtract(const Duration(days: 1)),
        ),
      ]);

      final images = storageService.getAllImages();

      // Total images: 1 + 2 + 1 = 4
      expect(images.length, 4);

      // Verify content
      expect(images.any((i) => i.base64Image == 'base64_img_1'), true);
      expect(images.any((i) => i.base64Image == 'base64_img_2'), true);
      expect(images.any((i) => i.base64Image == 'base64_img_3'), true);
      expect(images.any((i) => i.base64Image == 'base64_img_old'), true);

      // Verify associations
      final img1 = images.firstWhere((i) => i.base64Image == 'base64_img_1');
      expect(img1.session.id, '1');
      expect(img1.message.content, 'Look at this');
    });

    test('getAllImages sorts by timestamp descending', () {
      final now = DateTime.now();
      storageService.setMockSessions([
        ChatSession(
          id: '1',
          title: 'Recent',
          model: 'test',
          messages: [
            ChatMessage(
              role: 'user',
              content: 'Newest',
              timestamp: now,
              images: ['img_newest'],
            ),
          ],
          createdAt: now,
        ),
        ChatSession(
          id: '2',
          title: 'Old',
          model: 'test',
          messages: [
            ChatMessage(
              role: 'user',
              content: 'Oldest',
              timestamp: now.subtract(const Duration(days: 10)),
              images: ['img_oldest'],
            ),
          ],
          createdAt: now.subtract(const Duration(days: 10)),
        ),
        ChatSession(
          id: '3',
          title: 'Middle',
          model: 'test',
          messages: [
            ChatMessage(
              role: 'user',
              content: 'Middle',
              timestamp: now.subtract(const Duration(days: 1)),
              images: ['img_middle'],
            ),
          ],
          createdAt: now.subtract(const Duration(days: 1)),
        ),
      ]);

      final images = storageService.getAllImages();
      expect(images.length, 3);
      expect(images[0].base64Image, 'img_newest');
      expect(images[1].base64Image, 'img_middle');
      expect(images[2].base64Image, 'img_oldest');
    });
  });
}
