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
  group('StorageService Media Tests', () {
    late TestStorageService service;
    late List<ChatSession> sessions;

    setUp(() {
      final now = DateTime.now();
      sessions = [
        ChatSession(
          id: '1',
          title: 'Chat 1',
          model: 'llama3',
          messages: [
            ChatMessage(role: 'user', content: 'Image 1', timestamp: now, images: ['base64_img_1']),
            ChatMessage(role: 'assistant', content: 'Reply', timestamp: now),
          ],
          createdAt: now,
        ),
        ChatSession(
          id: '2',
          title: 'Chat 2',
          model: 'llama3',
          messages: [
            ChatMessage(role: 'user', content: 'Multi Images', timestamp: now.subtract(const Duration(minutes: 5)), images: ['base64_img_2', 'base64_img_3']),
          ],
          createdAt: now.subtract(const Duration(minutes: 5)),
        ),
        ChatSession(
          id: '3',
          title: 'Chat 3',
          model: 'mistral',
          messages: [
            ChatMessage(role: 'user', content: 'No Image', timestamp: now.subtract(const Duration(days: 1))),
          ],
          createdAt: now.subtract(const Duration(days: 1)),
        ),
      ];

      service = TestStorageService(sessions);
    });

    test('getAllMedia aggregates images correctly', () {
      final media = service.getAllMedia();

      expect(media.length, 3); // 1 from chat 1, 2 from chat 2

      // Check order (should be descending by timestamp)
      // Chat 1 is 'now', Chat 2 is 'now - 5 min'
      expect(media[0].imageUrl, 'base64_img_1');
      expect(media[0].chatId, '1');
      expect(media[0].messageContent, 'Image 1');

      // Next two should be from chat 2
      expect(media[1].chatId, '2');
      expect(media[2].chatId, '2');

      final imagesChat2 = {media[1].imageUrl, media[2].imageUrl};
      expect(imagesChat2.contains('base64_img_2'), true);
      expect(imagesChat2.contains('base64_img_3'), true);
    });

    test('getAllMedia handles empty sessions', () {
      service = TestStorageService([]);
      final media = service.getAllMedia();
      expect(media.isEmpty, true);
    });

     test('getAllMedia handles sessions without images', () {
       // Only session 3
      service = TestStorageService([sessions[2]]);
      final media = service.getAllMedia();
      expect(media.isEmpty, true);
    });
  });
}
