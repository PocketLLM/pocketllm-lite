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

    test('getAllImages returns empty list when no sessions', () {
      storageService.setMockSessions([]);
      final images = storageService.getAllImages();
      expect(images, isEmpty);
    });

    test('getAllImages returns empty list when no images in sessions', () {
      storageService.setMockSessions([
        ChatSession(
          id: '1',
          title: 'Chat 1',
          model: 'model',
          messages: [
            ChatMessage(
              role: 'user',
              content: 'hello',
              timestamp: DateTime.now(),
            ),
          ],
          createdAt: DateTime.now(),
        ),
      ]);
      final images = storageService.getAllImages();
      expect(images, isEmpty);
    });

    test('getAllImages extracts images correctly', () {
      final now = DateTime.now();
      storageService.setMockSessions([
        ChatSession(
          id: '1',
          title: 'Chat 1',
          model: 'model',
          messages: [
            ChatMessage(
              role: 'user',
              content: 'here is an image',
              timestamp: now,
              images: ['base64_img_1'],
            ),
          ],
          createdAt: now,
        ),
        ChatSession(
          id: '2',
          title: 'Chat 2',
          model: 'model',
          messages: [
            ChatMessage(
              role: 'user',
              content: 'two images',
              timestamp: now.add(const Duration(minutes: 5)),
              images: ['base64_img_2', 'base64_img_3'],
            ),
          ],
          createdAt: now,
        ),
      ]);

      final images = storageService.getAllImages();

      expect(images.length, 3);

      // Sorted by newest first (timestamp)
      // Chat 2 message is 5 mins later than Chat 1
      expect(
        images[0].base64Content,
        'base64_img_2',
      ); // From Chat 2 (first in list)
      expect(
        images[1].base64Content,
        'base64_img_3',
      ); // From Chat 2 (second in list)
      // Note: order within same message depends on iteration order.
      // Current impl adds them in order. Sort is stable? Or just by timestamp.
      // If timestamps are identical (same message), order is preserved?
      // Actually `sort` in Dart is stable.

      // Let's check IDs
      expect(images[0].chatId, '2');
      expect(images[1].chatId, '2');

      expect(images[2].base64Content, 'base64_img_1');
      expect(images[2].chatId, '1');
    });

    test('getAllImages generates unique IDs for duplicate images', () {
      final now = DateTime.now();
      storageService.setMockSessions([
        ChatSession(
          id: '1',
          title: 'Chat 1',
          model: 'model',
          messages: [
            ChatMessage(
              role: 'user',
              content: 'duplicate images',
              timestamp: now,
              // Same image twice
              images: ['base64_img_1', 'base64_img_1'],
            ),
          ],
          createdAt: now,
        ),
      ]);

      final images = storageService.getAllImages();

      expect(images.length, 2);
      expect(images[0].base64Content, 'base64_img_1');
      expect(images[1].base64Content, 'base64_img_1');

      // IDs should be different
      expect(images[0].id, isNot(equals(images[1].id)));

      // Check ID format (ChatID_Timestamp_Hash_Index)
      expect(images[0].id.endsWith('_0'), true);
      expect(images[1].id.endsWith('_1'), true);
    });
  });
}
