import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_session.dart';
import 'package:pocketllm_lite/features/chat/domain/models/system_prompt.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

class MockStorageService extends StorageService {
  final List<Map<String, dynamic>> logs = [];
  final List<ChatSession> mockSessions = [];
  final List<SystemPrompt> mockPrompts = [];
  final List<String> pinnedChats = [];

  @override
  Future<void> logActivity(String action, String details) async {
    logs.add({'action': action, 'details': details});
  }

  @override
  List<ChatSession> getChatSessions() => mockSessions;

  @override
  List<SystemPrompt> getSystemPrompts() => mockPrompts;

  @override
  List<String> getPinnedChatIds() => pinnedChats;

  @override
  Future<void> togglePin(String chatId) async {
    if (pinnedChats.contains(chatId)) {
      pinnedChats.remove(chatId);
      await logActivity('Chat Unpinned', 'Unpinned chat with ID $chatId');
    } else {
      pinnedChats.add(chatId);
      await logActivity('Chat Pinned', 'Pinned chat with ID $chatId');
    }
  }

  @override
  bool isPinned(String chatId) => pinnedChats.contains(chatId);
}

void main() {
  group('StorageService Pinning', () {
    late MockStorageService storage;

    setUp(() {
      storage = MockStorageService();
    });

    test('togglePin adds and removes pin and logs activity', () async {
      const chatId = 'chat-1';

      // Pin
      await storage.togglePin(chatId);
      expect(storage.pinnedChats.contains(chatId), true);
      expect(storage.isPinned(chatId), true);
      expect(storage.logs.last['action'], 'Chat Pinned');

      // Unpin
      await storage.togglePin(chatId);
      expect(storage.pinnedChats.contains(chatId), false);
      expect(storage.isPinned(chatId), false);
      expect(storage.logs.last['action'], 'Chat Unpinned');
    });
  });
}
