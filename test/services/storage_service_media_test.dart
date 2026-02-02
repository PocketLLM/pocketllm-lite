import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_session.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_message.dart';
import 'package:pocketllm_lite/services/storage_service.dart';
import 'package:pocketllm_lite/features/media/domain/models/media_item.dart';

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
             ChatMessage(
              role: 'assistant',
              content: 'Response',
              timestamp: now.add(const Duration(seconds: 1)),
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
              role: 'user',
              content: 'No image',
              timestamp: now.subtract(const Duration(days: 1)),
            ),
          ],
          createdAt: now.subtract(const Duration(days: 1)),
        ),
        ChatSession(
          id: '3',
          title: 'Chat 3',
          model: 'llama3',
          messages: [
            ChatMessage(
              role: 'user',
              content: 'Two images',
              timestamp: now.subtract(const Duration(days: 2)),
              images: ['base64_2', 'base64_3'],
            ),
          ],
          createdAt: now.subtract(const Duration(days: 2)),
        ),
      ];

      storageService.setMockSessions(sessions);
    });

    test('getAllImages returns all images sorted by timestamp desc', () {
      final results = storageService.getAllImages();

      expect(results.length, 3);

      // Sort order check (newest first)
      // Chat 1 (now) > Chat 3 (2 days ago)

      expect(results[0].base64Content, 'base64_1');
      expect(results[0].chatId, '1');

      // Since images in same message have same timestamp, their relative order is stable based on insertion
      // but let's just check they are present.

      final chat3Images = results.where((i) => i.chatId == '3').toList();
      expect(chat3Images.length, 2);
      expect(chat3Images.map((i) => i.base64Content), containsAll(['base64_2', 'base64_3']));
    });

    test('getAllImages returns empty list if no images', () {
      storageService.setMockSessions([
         ChatSession(
          id: '4',
          title: 'No Images',
          model: 'llama3',
          messages: [
            ChatMessage(role: 'user', content: 'text', timestamp: DateTime.now())
          ],
          createdAt: DateTime.now(),
        ),
      ]);

      final results = storageService.getAllImages();
      expect(results.isEmpty, true);
    });
  });
}
