import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_session.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_message.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

class TestStorageService extends StorageService {
  final List<ChatSession> _mockSessions;

  TestStorageService(this._mockSessions);

  @override
  List<ChatSession> getChatSessions() {
    return _mockSessions;
  }
}

void main() {
  group('StorageService Media Gallery Tests', () {
    late TestStorageService service;
    late List<ChatSession> sessions;
    final now = DateTime.now();

    setUp(() {
      sessions = [
        ChatSession(
          id: 'chat1',
          title: 'Chat 1',
          model: 'model1',
          createdAt: now.subtract(const Duration(hours: 2)),
          messages: [
            ChatMessage(
              role: 'user',
              content: 'Image 1',
              timestamp: now.subtract(const Duration(hours: 1)),
              images: ['base64_1'],
            ),
            ChatMessage(
              role: 'assistant',
              content: 'Text only',
              timestamp: now.subtract(const Duration(minutes: 50)),
            ),
          ],
        ),
        ChatSession(
          id: 'chat2',
          title: 'Chat 2',
          model: 'model2',
          createdAt: now.subtract(const Duration(hours: 5)),
          messages: [
            ChatMessage(
              role: 'user',
              content: 'Multiple Images',
              timestamp: now.subtract(const Duration(hours: 4)),
              images: ['base64_2', 'base64_3'],
            ),
          ],
        ),
        ChatSession(
          id: 'chat3',
          title: 'Chat 3',
          model: 'model1',
          createdAt: now.subtract(const Duration(days: 1)),
          messages: [],
        ),
      ];
      service = TestStorageService(sessions);
    });

    test('getAllImages aggregates images from all sessions', () {
      final images = service.getAllImages();

      // Should have 3 images total (1 from chat1, 2 from chat2)
      expect(images.length, 3);
    });

    test('getAllImages returns sorted images (newest first)', () {
      final images = service.getAllImages();

      // chat1 message is newer (1 hour ago) than chat2 message (4 hours ago)
      expect(images[0].chatId, 'chat1');
      expect(images[0].base64Data, 'base64_1');

      expect(images[1].chatId, 'chat2');
      // For multiple images in same message, order depends on implementation (likely list order)
      // but timestamp is same.
      expect(images[1].timestamp, images[2].timestamp);
    });

    test('getAllImages constructs correct MediaItem', () {
      final images = service.getAllImages();
      final item = images.firstWhere((i) => i.base64Data == 'base64_1');

      expect(item.chatId, 'chat1');
      expect(item.index, 0);
      expect(item.id, contains('chat1'));
    });
  });
}
