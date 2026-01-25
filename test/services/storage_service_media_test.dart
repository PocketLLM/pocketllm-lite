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
  group('StorageService Media Gallery Logic', () {
    late TestStorageService storageService;

    setUp(() {
      storageService = TestStorageService();
    });

    test('getMediaGallery returns empty list when no images', () {
      storageService.setMockSessions([
        ChatSession(
          id: '1',
          title: 'No Images',
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

      final gallery = storageService.getMediaGallery();
      expect(gallery.isEmpty, true);
    });

    test('getMediaGallery aggregates images correctly', () {
      final now = DateTime.now();
      storageService.setMockSessions([
        ChatSession(
          id: '1',
          title: 'With Images',
          model: 'llama3',
          messages: [
            ChatMessage(
              role: 'user',
              content: 'Here is an image',
              timestamp: now,
              images: ['base64_1'],
            ),
            ChatMessage(
              role: 'assistant',
              content: 'Cool',
              timestamp: now.add(const Duration(seconds: 1)),
            ),
             ChatMessage(
              role: 'user',
              content: 'Another one',
              timestamp: now.add(const Duration(seconds: 2)),
              images: ['base64_2', 'base64_3'],
            ),
          ],
          createdAt: now,
        ),
      ]);

      final gallery = storageService.getMediaGallery();
      expect(gallery.length, 3);

      // Note: Sorted by timestamp desc (newest first)
      // 'base64_3' and 'base64_2' have same timestamp?
      // Wait, ChatMessage has one timestamp.
      // So 'base64_2' and 'base64_3' are in the same message.
      // The sort is by timestamp.
      // Stable sort or arbitrary?
      // Since timestamps are equal, order depends on implementation if sort is stable.
      // Dart's sort is stable.
      // But they are added in order 1, 2, 3.
      // If I sort descending:
      // 2 and 3 are newer (t+2s). 1 is older (t).
      // Between 2 and 3? They have same timestamp.
      // The sort function returns 0.
      // If stable, original order is preserved.
      // Original order in list: 2 then 3 (added in loop).
      // So 2, 3, 1?
      // Wait, if I add them 2 then 3.
      // And sort by timestamp desc.
      // Comparison of 2 and 3 gives 0.
      // Stable sort keeps 2 before 3.
      // So order should be 2, 3, 1?

      // Let's check expectation.
      // Actually, my test implementation adds them:
      // msg1 (images: [1]) -> added 1.
      // msg3 (images: [2, 3]) -> added 2, then 3.
      // List: [1, 2, 3].
      // Sort desc by timestamp.
      // 2 and 3 > 1.
      // 2 == 3.
      // So [2, 3, 1] if stable.

      // Let's verify.

      expect(gallery[2].base64Content, 'base64_1');
      // I won't be strict about 2 vs 3 order unless I add index to sort key.
      // But let's see.
      expect(gallery.map((e) => e.base64Content).toSet(), {'base64_1', 'base64_2', 'base64_3'});
    });

    test('getMediaGallery sorts by timestamp descending across chats', () {
      final now = DateTime.now();
      storageService.setMockSessions([
        ChatSession(
          id: '1',
          title: 'Chat 1',
          model: 'llama3',
          messages: [
            ChatMessage(
              role: 'user',
              content: 'Old Image',
              timestamp: now.subtract(const Duration(days: 1)),
              images: ['old'],
            ),
          ],
          createdAt: now.subtract(const Duration(days: 1)),
        ),
        ChatSession(
          id: '2',
          title: 'Chat 2',
          model: 'llama3',
          messages: [
            ChatMessage(
              role: 'user',
              content: 'New Image',
              timestamp: now,
              images: ['new'],
            ),
          ],
          createdAt: now,
        ),
      ]);

      final gallery = storageService.getMediaGallery();
      expect(gallery.length, 2);
      expect(gallery[0].base64Content, 'new');
      expect(gallery[1].base64Content, 'old');
    });
  });
}
