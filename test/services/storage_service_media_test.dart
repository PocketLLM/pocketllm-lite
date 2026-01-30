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
              content: 'Hi with image',
              timestamp: now,
              images: ['base64image1'],
            ),
            ChatMessage(
              role: 'assistant',
              content: 'Hello',
              timestamp: now.add(const Duration(seconds: 1)),
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
              content: 'Two images',
              timestamp: now.subtract(const Duration(days: 1)),
              images: ['base64image2', 'base64image3'],
            ),
          ],
          createdAt: now.subtract(const Duration(days: 1)),
        ),
        ChatSession(
          id: '3',
          title: 'Chat 3',
          model: 'mistral',
          messages: [
            ChatMessage(
              role: 'user',
              content: 'No images',
              timestamp: now.subtract(const Duration(days: 10)),
            ),
          ],
          createdAt: now.subtract(const Duration(days: 10)),
        ),
      ];

      service = TestStorageService(sessions);
    });

    test('getAllImages extracts all images correctly', () {
      final images = service.getAllImages();

      // Expect 3 images total (1 from Chat 1, 2 from Chat 2)
      expect(images.length, 3);

      // Verify image content
      expect(images.map((e) => e.base64Image), containsAll(['base64image1', 'base64image2', 'base64image3']));

      // Verify chat info
      expect(images.firstWhere((e) => e.base64Image == 'base64image1').chatId, '1');
      expect(images.firstWhere((e) => e.base64Image == 'base64image1').chatTitle, 'Chat 1');

      expect(images.firstWhere((e) => e.base64Image == 'base64image2').chatId, '2');
      expect(images.firstWhere((e) => e.base64Image == 'base64image3').chatId, '2');
    });

    test('getAllImages sorts by timestamp descending', () {
      final images = service.getAllImages();

      // Chat 1 is newest (now) -> image1
      // Chat 2 is older (now - 1 day) -> image2, image3

      expect(images[0].base64Image, 'base64image1');
      // The order of image2 and image3 depends on iteration order or exact timestamp if different.
      // Since they have same timestamp, stable sort or insertion order matters.
      // But we definitely know image1 is first.

      expect(images.last.timestamp.isBefore(images.first.timestamp), true);
    });

    test('getAllImages handles empty sessions', () {
      service = TestStorageService([]);
      final images = service.getAllImages();
      expect(images.isEmpty, true);
    });
  });
}
