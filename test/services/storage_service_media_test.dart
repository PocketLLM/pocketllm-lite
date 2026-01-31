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
            ChatMessage(
              role: 'user',
              content: 'Hi',
              timestamp: now,
              images: ['img1_base64'],
            ),
            ChatMessage(
              role: 'assistant',
              content: 'Hello',
              timestamp: now.add(const Duration(minutes: 1)),
            ),
          ],
          createdAt: now,
        ),
        ChatSession(
          id: '2',
          title: 'Chat 2',
          model: 'llama3',
          messages: [
            ChatMessage(
              role: 'user',
              content: 'Q',
              timestamp: now.add(const Duration(hours: 1)),
              images: ['img2_base64', 'img3_base64'],
            ),
          ],
          createdAt: now.add(const Duration(hours: 1)),
        ),
        ChatSession(
          id: '3',
          title: 'Chat 3',
          model: 'mistral',
          messages: [
            ChatMessage(role: 'user', content: 'A', timestamp: now.subtract(const Duration(days: 1))),
          ],
          createdAt: now.subtract(const Duration(days: 1)),
        ),
      ];

      service = TestStorageService(sessions);
    });

    test('getAllImages aggregates and sorts images correctly', () {
      final images = service.getAllImages();

      expect(images.length, 3);

      // Check content
      expect(images.any((i) => i.base64Content == 'img1_base64' && i.chatId == '1'), isTrue);
      expect(images.any((i) => i.base64Content == 'img2_base64' && i.chatId == '2'), isTrue);
      expect(images.any((i) => i.base64Content == 'img3_base64' && i.chatId == '2'), isTrue);

      // Check sorting (newest first)
      // img2/3 are from 'now + 1hr', img1 is 'now'
      expect(images[0].chatId, '2');
      expect(images[1].chatId, '2');
      expect(images[2].chatId, '1');
    });

    test('getAllImages handles empty sessions', () {
      service = TestStorageService([]);
      final images = service.getAllImages();
      expect(images, isEmpty);
    });

    test('getAllImages handles sessions with no images', () {
      sessions = [
        ChatSession(
          id: '4',
          title: 'No Images',
          model: 'llama3',
          messages: [ChatMessage(role: 'user', content: 'text', timestamp: DateTime.now())],
          createdAt: DateTime.now(),
        )
      ];
      service = TestStorageService(sessions);
      final images = service.getAllImages();
      expect(images, isEmpty);
    });
  });
}
