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

    setUp(() {
      storageService = TestStorageService();
    });

    test('getAllImages returns empty list when no sessions exist', () {
      storageService.setMockSessions([]);
      final images = storageService.getAllImages();
      expect(images, isEmpty);
    });

    test('getAllImages returns images from sessions', () {
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
              content: 'Look at this',
              timestamp: now,
              images: ['base64_img1', 'base64_img2'],
            ),
            ChatMessage(
              role: 'assistant',
              content: 'Nice',
              timestamp: now.add(const Duration(seconds: 1)),
            ),
          ],
        ),
        ChatSession(
          id: '2',
          title: 'Chat 2',
          model: 'model1',
          createdAt: now.subtract(const Duration(days: 1)),
          messages: [
            ChatMessage(
              role: 'user',
              content: 'Another one',
              timestamp: now.subtract(const Duration(days: 1)),
              images: ['base64_img3'],
            ),
          ],
        ),
      ];

      storageService.setMockSessions(sessions);
      final images = storageService.getAllImages();

      expect(images.length, 3);

      // Check first image (sorted by timestamp desc, so Chat 1 images are newer)
      // Note: timestamps for chat 1 are same (now), chat 2 is yesterday.
      // The implementation iterates sessions and adds images. Sorts at the end.

      // Verify contents
      expect(images.any((i) => i.base64Content == 'base64_img1'), true);
      expect(images.any((i) => i.base64Content == 'base64_img2'), true);
      expect(images.any((i) => i.base64Content == 'base64_img3'), true);

      // Verify metadata
      final img1 = images.firstWhere((i) => i.base64Content == 'base64_img1');
      expect(img1.chatId, '1');
      expect(img1.chatTitle, 'Chat 1');

      final img3 = images.firstWhere((i) => i.base64Content == 'base64_img3');
      expect(img3.chatId, '2');
      expect(img3.chatTitle, 'Chat 2');
    });

    test('getAllImages sorts by timestamp descending', () {
      final now = DateTime.now();
      final sessions = [
        ChatSession(
          id: '1',
          title: 'Old Chat',
          model: 'model1',
          createdAt: now.subtract(const Duration(days: 1)),
          messages: [
            ChatMessage(
              role: 'user',
              content: 'Old image',
              timestamp: now.subtract(const Duration(days: 1)),
              images: ['old_img'],
            ),
          ],
        ),
        ChatSession(
          id: '2',
          title: 'New Chat',
          model: 'model1',
          createdAt: now,
          messages: [
            ChatMessage(
              role: 'user',
              content: 'New image',
              timestamp: now,
              images: ['new_img'],
            ),
          ],
        ),
      ];

      storageService.setMockSessions(sessions);
      final images = storageService.getAllImages();

      expect(images.length, 2);
      expect(images[0].base64Content, 'new_img');
      expect(images[1].base64Content, 'old_img');
    });
  });
}
