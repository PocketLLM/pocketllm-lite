import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_message.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_session.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

class MockStorageService extends StorageService {
  List<ChatSession> mockSessions = [];
  final List<Map<String, dynamic>> logs = [];

  @override
  List<ChatSession> getChatSessions() => mockSessions;

  @override
  ChatSession? getChatSession(String id) {
    try {
      return mockSessions.firstWhere((s) => s.id == id);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> saveChatSession(ChatSession session, {bool log = true}) async {
    final index = mockSessions.indexWhere((s) => s.id == session.id);
    if (index != -1) {
      mockSessions[index] = session;
    } else {
      mockSessions.add(session);
    }
  }

  @override
  Future<void> logActivity(String action, String details) async {
    logs.add({'action': action, 'details': details});
  }
}

void main() {
  group('Media Gallery Tests', () {
    late MockStorageService storage;

    setUp(() {
      storage = MockStorageService();
    });

    test('getAllMedia returns correct items', () {
      final now = DateTime.now();
      storage.mockSessions = [
        ChatSession(
          id: '1',
          title: 'Chat 1',
          model: 'llama3',
          createdAt: now,
          messages: [
            ChatMessage(role: 'user', content: 'Hi', timestamp: now),
            ChatMessage(
              role: 'assistant',
              content: 'Image',
              timestamp: now,
              images: ['base64_1', 'base64_2'],
            ),
          ],
        ),
      ];

      final media = storage.getAllMedia();
      expect(media.length, 2);
      expect(media[0].chatId, '1');
      expect(media[0].base64Content, 'base64_1');
      expect(media[0].imageIndex, 0);
      expect(media[1].base64Content, 'base64_2');
      expect(media[1].imageIndex, 1);
    });

    test('deleteMedia removes image and updates session', () async {
      final now = DateTime.now();
      storage.mockSessions = [
        ChatSession(
          id: '1',
          title: 'Chat 1',
          model: 'llama3',
          createdAt: now,
          messages: [
            ChatMessage(
              role: 'user',
              content: 'Text with image',
              timestamp: now,
              images: ['base64_1', 'base64_2'],
            ),
          ],
        ),
      ];

      final media = storage.getAllMedia();
      // Delete the first image (index 0)
      await storage.deleteMedia([media[0]]);

      final session = storage.getChatSession('1');
      expect(session!.messages.first.images!.length, 1);
      expect(session.messages.first.images!.first, 'base64_2');
      expect(storage.logs.length, 1);
      expect(storage.logs.first['action'], 'Media Deleted');
    });

    test('deleteMedia removes message if empty', () async {
      final now = DateTime.now();
      storage.mockSessions = [
        ChatSession(
          id: '1',
          title: 'Chat 1',
          model: 'llama3',
          createdAt: now,
          messages: [
            ChatMessage(
              role: 'user',
              content: '', // Empty content
              timestamp: now,
              images: ['base64_1'],
            ),
          ],
        ),
      ];

      final media = storage.getAllMedia();
      await storage.deleteMedia([media[0]]);

      final session = storage.getChatSession('1');
      expect(session!.messages.isEmpty, true);
    });
  });
}
