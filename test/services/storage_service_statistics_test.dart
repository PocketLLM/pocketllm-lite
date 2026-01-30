import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/core/constants/app_constants.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_session.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_message.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

// Subclass to override data accessors for testing
class TestStorageService extends StorageService {
  final List<ChatSession> _mockSessions;
  final Map<String, dynamic> _mockSettings;

  TestStorageService(this._mockSessions, this._mockSettings);

  @override
  List<ChatSession> getChatSessions() {
    return _mockSessions;
  }

  @override
  dynamic getSetting(String key, {dynamic defaultValue}) {
    return _mockSettings[key] ?? defaultValue;
  }
}

void main() {
  group('StorageService Statistics Tests', () {
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
            ChatMessage(role: 'user', content: 'Hi', timestamp: now),
            ChatMessage(role: 'assistant', content: 'Hello', timestamp: now),
          ],
          createdAt: now,
        ),
        ChatSession(
          id: '2',
          title: 'Chat 2',
          model: 'llama3',
          messages: [ChatMessage(role: 'user', content: 'Q', timestamp: now)],
          createdAt: now,
        ),
        ChatSession(
          id: '3',
          title: 'Chat 3',
          model: 'mistral',
          messages: [
            ChatMessage(
              role: 'user',
              content: 'A',
              timestamp: now.subtract(const Duration(days: 10)),
            ),
          ],
          createdAt: now.subtract(const Duration(days: 10)),
        ),
      ];

      final settings = {AppConstants.totalTokensUsedKey: 5000};

      service = TestStorageService(sessions, settings);
    });

    test('getUsageStatistics calculates correct values', () {
      final stats = service.getUsageStatistics();

      expect(stats.totalChats, 3);
      expect(stats.totalMessages, 4); // 2 + 1 + 1
      expect(stats.totalTokensUsed, 5000);
      expect(stats.chatsLast7Days, 2); // Chat 1 and Chat 2

      expect(stats.modelUsage['llama3'], 2);
      expect(stats.modelUsage['mistral'], 1);

      expect(stats.mostUsedModel, 'llama3');
    });

    test('getUsageStatistics handles empty data', () {
      service = TestStorageService([], {});
      final stats = service.getUsageStatistics();

      expect(stats.totalChats, 0);
      expect(stats.totalMessages, 0);
      expect(stats.totalTokensUsed, 0);
      expect(stats.modelUsage.isEmpty, true);
      expect(stats.mostUsedModel, 'None');
    });
  });
}
