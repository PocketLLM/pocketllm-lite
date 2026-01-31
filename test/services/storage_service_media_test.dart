import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_message.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_session.dart';
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
  group('StorageService Media', () {
    test('getAllImages extracts images from sessions and sorts by timestamp', () {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));

      final msg1 = ChatMessage(role: 'user', content: 'img1', timestamp: yesterday, images: ['base64_1']);
      final msg2 = ChatMessage(role: 'user', content: 'img2', timestamp: now, images: ['base64_2', 'base64_3']);
      final msg3 = ChatMessage(role: 'user', content: 'text', timestamp: now, images: null);

      final session1 = ChatSession(
        id: 's1',
        title: 't1',
        model: 'm1',
        createdAt: yesterday,
        messages: [msg1]
      );

      final session2 = ChatSession(
        id: 's2',
        title: 't2',
        model: 'm1',
        createdAt: now,
        messages: [msg2, msg3]
      );

      final service = TestStorageService([session1, session2]);
      final images = service.getAllImages();

      expect(images.length, 3);

      // Sorted by timestamp desc (msg2 is newer than msg1)
      // msg2 has 2 images. Both share same timestamp.
      expect(images[0].base64, isIn(['base64_2', 'base64_3']));
      expect(images[1].base64, isIn(['base64_2', 'base64_3']));
      expect(images[2].base64, 'base64_1');

      expect(images[0].chatId, 's2');
      expect(images[2].chatId, 's1');
    });
  });
}
