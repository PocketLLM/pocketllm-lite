import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_session.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_message.dart';
import 'package:pocketllm_lite/features/gallery/domain/models/media_item.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

class TestStorageService extends StorageService {
  List<ChatSession> _mockSessions = [];
  ChatSession? _lastSavedSession;

  void setMockSessions(List<ChatSession> sessions) {
    _mockSessions = sessions;
  }

  ChatSession? getLastSavedSession() => _lastSavedSession;

  @override
  List<ChatSession> getChatSessions() {
    return _mockSessions;
  }

  @override
  ChatSession? getChatSession(String id) {
    try {
      return _mockSessions.firstWhere((s) => s.id == id);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> saveChatSession(ChatSession session, {bool log = true}) async {
    _lastSavedSession = session;
    // Update mock sessions to reflect change
    final index = _mockSessions.indexWhere((s) => s.id == session.id);
    if (index != -1) {
      _mockSessions[index] = session;
    }
  }

  @override
  Future<void> logActivity(String action, String details) async {
    // No-op for test
  }
}

void main() {
  group('StorageService Gallery Logic', () {
    late TestStorageService storageService;
    late List<ChatSession> sessions;
    late DateTime now;

    setUp(() {
      storageService = TestStorageService();
      now = DateTime.now();
    });

    test('getGalleryImages aggregates images correctly', () {
      sessions = [
        ChatSession(
          id: '1',
          title: 'Chat 1',
          model: 'model',
          messages: [
            ChatMessage(
              role: 'user',
              content: 'Image 1',
              timestamp: now,
              images: ['base64_1'],
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
              content: 'Image 2 & 3',
              timestamp: now.subtract(const Duration(minutes: 10)),
              images: ['base64_2', 'base64_3'],
            ),
          ],
          createdAt: now,
        ),
      ];
      storageService.setMockSessions(sessions);

      final images = storageService.getGalleryImages();

      expect(images.length, 3);
      // Sorted by timestamp desc (newest first).
      // Chat 1 is 'now', Chat 2 is 'now - 10m'. So Chat 1 first.
      expect(images[0].base64Image, 'base64_1');

      // Wait, Chat 2 messages are older, so Chat 1 should be first.
      // images[0] is base64_1.
      // Then Chat 2's images.

      expect(images[1].base64Image, 'base64_2');
      expect(images[2].base64Image, 'base64_3');

      expect(images[0].chatId, '1');
      expect(images[1].chatId, '2');
      expect(images[1].imageIndex, 0);
      expect(images[2].imageIndex, 1);
    });

    test('deleteImage removes image from message', () async {
       sessions = [
        ChatSession(
          id: '1',
          title: 'Chat 1',
          model: 'model',
          messages: [
            ChatMessage(
              role: 'user',
              content: 'Msg',
              timestamp: now,
              images: ['img1', 'img2'],
            ),
          ],
          createdAt: now,
        ),
      ];
      storageService.setMockSessions(sessions);

      // Delete 'img1' (index 0)
      final itemToDelete = MediaItem(
        chatId: '1',
        chatTitle: 'Chat 1',
        messageTimestamp: now,
        imageIndex: 0,
        base64Image: 'img1'
      );

      await storageService.deleteImage(itemToDelete);

      final savedSession = storageService.getLastSavedSession();
      expect(savedSession, isNotNull);
      expect(savedSession!.messages.length, 1);
      expect(savedSession.messages[0].images, ['img2']);
    });

    test('deleteImage deletes message if empty after image removal', () async {
       sessions = [
        ChatSession(
          id: '1',
          title: 'Chat 1',
          model: 'model',
          messages: [
            ChatMessage(
              role: 'user',
              content: '', // Empty content
              timestamp: now,
              images: ['img1'],
            ),
          ],
          createdAt: now,
        ),
      ];
      storageService.setMockSessions(sessions);

      final itemToDelete = MediaItem(
        chatId: '1',
        chatTitle: 'Chat 1',
        messageTimestamp: now,
        imageIndex: 0,
        base64Image: 'img1'
      );

      await storageService.deleteImage(itemToDelete);

      final savedSession = storageService.getLastSavedSession();
      expect(savedSession, isNotNull);
      expect(savedSession!.messages.isEmpty, true);
    });
  });
}
