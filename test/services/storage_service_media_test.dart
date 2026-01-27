import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_session.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_message.dart';
import 'package:pocketllm_lite/features/chat/domain/models/media_item.dart';
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
  group('StorageService Media Gallery Logic', () {
    late TestStorageService storageService;
    late List<ChatSession> sessions;

    setUp(() {
      storageService = TestStorageService();

      final now = DateTime.now();
      sessions = [
        // Chat 1: 1 message with 2 images
        ChatSession(
          id: '1',
          title: 'Chat 1',
          model: 'llama3',
          messages: [
            ChatMessage(
              role: 'user',
              content: 'Look at these',
              timestamp: now,
              images: ['img1', 'img2'],
            ),
          ],
          createdAt: now,
        ),
        // Chat 2: No images
        ChatSession(
          id: '2',
          title: 'Chat 2',
          model: 'mistral',
          messages: [
            ChatMessage(
              role: 'user',
              content: 'Hello',
              timestamp: now.subtract(const Duration(minutes: 5)),
            ),
          ],
          createdAt: now.subtract(const Duration(minutes: 5)),
        ),
        // Chat 3: 2 messages, 1 image each
        ChatSession(
          id: '3',
          title: 'Chat 3',
          model: 'llama3',
          messages: [
            ChatMessage(
              role: 'user',
              content: 'Image 3',
              timestamp: now.subtract(const Duration(minutes: 10)),
              images: ['img3'],
            ),
            ChatMessage(
              role: 'assistant',
              content: 'Cool',
              timestamp: now.subtract(const Duration(minutes: 9)),
            ),
            ChatMessage(
              role: 'user',
              content: 'Image 4',
              timestamp: now.subtract(const Duration(minutes: 8)),
              images: ['img4'],
            ),
          ],
          createdAt: now.subtract(const Duration(minutes: 10)),
        ),
      ];

      storageService.setMockSessions(sessions);
    });

    test('getAllImages extracts all images correctly', () {
      final images = storageService.getAllImages();

      // Total images: 2 (Chat 1) + 0 (Chat 2) + 2 (Chat 3) = 4
      expect(images.length, 4);

      // Verify content
      final imageContents = images.map((i) => i.base64Image).toSet();
      expect(imageContents.containsAll(['img1', 'img2', 'img3', 'img4']), true);
    });

    test('getAllImages sorts by timestamp descending', () {
      final images = storageService.getAllImages();

      // Check order
      // Chat 1 (now) -> img1, img2 (order within message doesn't strictly matter for sort but they have same timestamp)
      // Chat 3 Msg 2 (now-8m) -> img4
      // Chat 3 Msg 1 (now-10m) -> img3

      expect(images[0].chatId, '1'); // img1 or img2
      expect(images[1].chatId, '1'); // img1 or img2
      expect(images[2].base64Image, 'img4'); // Newer message in Chat 3
      expect(images[3].base64Image, 'img3'); // Older message in Chat 3
    });

    test('getAllImages creates correct MediaItems', () {
      final images = storageService.getAllImages();
      final item = images.firstWhere((i) => i.base64Image == 'img4');

      expect(item.chatId, '3');
      expect(item.base64Image, 'img4');
      expect(item.timestamp, isNotNull);
    });
  });
}
