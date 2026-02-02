import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_session.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_message.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

// Subclass to override data accessors for testing
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
    test('getAllImages returns empty list when no images', () {
      final service = TestStorageService([]);
      final images = service.getAllImages();
      expect(images, isEmpty);
    });

    test('getAllImages aggregates images correctly', () {
      final now = DateTime.now();
      final sessions = [
        ChatSession(
          id: 's1',
          title: 'Session 1',
          model: 'model1',
          createdAt: now,
          messages: [
            ChatMessage(
              role: 'user',
              content: 'text only',
              timestamp: now,
            ),
            ChatMessage(
              role: 'assistant',
              content: 'one image',
              timestamp: now.add(const Duration(seconds: 1)),
              images: ['img1'],
            ),
          ],
        ),
        ChatSession(
          id: 's2',
          title: 'Session 2',
          model: 'model1',
          createdAt: now,
          messages: [
            ChatMessage(
              role: 'user',
              content: 'two images',
              timestamp: now.add(const Duration(seconds: 2)),
              images: ['img2', 'img3'],
            ),
          ],
        ),
      ];

      final service = TestStorageService(sessions);
      final images = service.getAllImages();

      expect(images.length, 3);

      // Sort is mainly by timestamp.
      // img2 and img3 have same timestamp (now+2s). img1 has (now+1s).
      // So img2 and img3 should be first, img1 last.
      expect(images[2].base64Data, 'img1');

      // Check that the first two are indeed img2 and img3 (order might vary if sort unstable)
      final firstTwoData = [images[0].base64Data, images[1].base64Data];
      expect(firstTwoData, containsAll(['img2', 'img3']));

      // Check properties for img1
      expect(images[2].chatId, 's1');
      expect(images[2].chatTitle, 'Session 1');
      expect(images[2].id, 's1_1_0'); // session 1, message 1, image 0
    });
  });
}
