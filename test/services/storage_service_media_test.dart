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
          title: 'Chat with Image',
          model: 'llama3',
          messages: [
            ChatMessage(
              role: 'user',
              content: 'Here is an image',
              timestamp: now,
              images: ['base64image1'],
            ),
          ],
          createdAt: now,
        ),
        ChatSession(
          id: '2',
          title: 'Chat with Multiple Images',
          model: 'llava',
          messages: [
            ChatMessage(
              role: 'user',
              content: 'Two images',
              timestamp: now.subtract(const Duration(minutes: 5)),
              images: ['base64image2', 'base64image3'],
            ),
          ],
          createdAt: now.subtract(const Duration(minutes: 5)),
        ),
        ChatSession(
          id: '3',
          title: 'Text Only',
          model: 'llama3',
          messages: [
            ChatMessage(
              role: 'user',
              content: 'No images here',
              timestamp: now.subtract(const Duration(hours: 1)),
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

      // Check first image (newest) - from Chat 1
      expect(images[0].base64Content, 'base64image1');
      expect(images[0].chatId, '1');

      // Check subsequent images - from Chat 2
      // Note: Sort is stable or based on insertion order for same timestamp?
      // Actually messages have slightly different timestamps usually, but here I reused `now` for chat 1 and `now-5min` for chat 2.
      // Chat 2 has 2 images in same message.

      expect(images[1].chatId, '2');
      expect(images[2].chatId, '2');

      final contentSet = {images[1].base64Content, images[2].base64Content};
      expect(contentSet.contains('base64image2'), true);
      expect(contentSet.contains('base64image3'), true);
    });

    test('MediaItem ID generation is unique', () {
      final images = storageService.getAllImages();
      final ids = images.map((i) => i.id).toSet();
      expect(ids.length, 3);
    });
  });
}
