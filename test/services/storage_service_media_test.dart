import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_session.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_message.dart';
import 'package:pocketllm_lite/services/storage_service.dart';
import 'package:pocketllm_lite/features/media/domain/models/media_item.dart';

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

    test('getAllImages extracts images correctly', () {
      final now = DateTime.now();
      final sessions = [
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
              content: 'No image',
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
              content: 'Two Images',
              timestamp: now.subtract(const Duration(days: 1)),
              images: ['base64_2', 'base64_3'],
            ),
          ],
          createdAt: now.subtract(const Duration(days: 1)),
        ),
      ];

      service = TestStorageService(sessions);
      final images = service.getAllImages();

      expect(images.length, 3);

      // Sorted by timestamp desc (so Chat 1 first)
      expect(images[0].imagePath, 'base64_1');
      expect(images[0].chatId, '1');
      expect(images[0].chatTitle, 'Chat 1');

      // Next two are from Chat 2 (older)
      // Since they are in the same message, order depends on iteration order (List order)
      // Our implementation adds them in loop order.
      // And then sorts by timestamp.
      // Since timestamps are identical for images in same message,
      // sort is stable or depends on implementation.
      // Wait, list sort is not guaranteed stable in Dart across all platforms, but usually is.
      // However, if timestamps are equal, any order is acceptable for images in same message.

      expect(images.map((i) => i.imagePath), containsAll(['base64_2', 'base64_3']));
      expect(images[1].chatId, '2');
      expect(images[2].chatId, '2');
    });

    test('getAllImages handles empty sessions', () {
      service = TestStorageService([]);
      final images = service.getAllImages();
      expect(images, isEmpty);
    });

    test('getAllImages handles messages without images', () {
      final sessions = [
        ChatSession(
          id: '1',
          title: 'No Images',
          model: 'llama3',
          messages: [
            ChatMessage(
              role: 'user',
              content: 'Text only',
              timestamp: DateTime.now(),
            ),
          ],
          createdAt: DateTime.now(),
        ),
      ];
      service = TestStorageService(sessions);
      final images = service.getAllImages();
      expect(images, isEmpty);
    });
  });
}
