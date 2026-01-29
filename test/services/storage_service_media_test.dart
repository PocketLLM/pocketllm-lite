import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_session.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_message.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

// Test Mock
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
      final now = DateTime.now();

      storageService.setMockSessions([
        ChatSession(
          id: '1',
          title: 'Chat 1',
          model: 'model1',
          createdAt: now,
          messages: [
            ChatMessage(
              role: 'user',
              content: 'msg1',
              timestamp: now.subtract(const Duration(minutes: 5)),
              images: ['image1_base64'],
            ),
            ChatMessage(
              role: 'assistant',
              content: 'msg2',
              timestamp: now.subtract(const Duration(minutes: 4)),
            ),
          ],
        ),
        ChatSession(
          id: '2',
          title: 'Chat 2',
          model: 'model1',
          createdAt: now,
          messages: [
            ChatMessage(
              role: 'user',
              content: 'msg3',
              timestamp: now.subtract(const Duration(minutes: 2)),
              images: ['image2_base64', 'image3_base64'],
            ),
          ],
        ),
      ]);
    });

    test('getAllImages returns all images sorted by date desc', () {
      final images = storageService.getAllImages();

      expect(images.length, 3);

      // Sorted by date desc?
      // Timestamps:
      // image1: now - 5 min
      // image2, image3: now - 2 min

      // Expect image2/3 (newer) first, then image1.
      // Order of 2 and 3 depends on list order, but they have same timestamp.
      // 2 and 3 are from same message.
      expect(images[0].imageBase64, anyOf('image2_base64', 'image3_base64'));
      expect(images[1].imageBase64, anyOf('image2_base64', 'image3_base64'));
      expect(images[2].imageBase64, 'image1_base64');

      // Verify chatId
      expect(images[0].chatId, '2');
      expect(images[2].chatId, '1');
    });
  });
}
