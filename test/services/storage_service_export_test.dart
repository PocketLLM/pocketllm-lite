import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_session.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_message.dart';
import 'package:pocketllm_lite/features/chat/domain/models/system_prompt.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

// Subclass to override data accessors for testing
class TestStorageService extends StorageService {
  final List<ChatSession> _mockSessions;

  TestStorageService(this._mockSessions);

  @override
  List<ChatSession> getChatSessions() {
    return _mockSessions;
  }

  @override
  Future<void> logActivity(String action, String details) async {
    // No-op for testing
  }

  @override
  List<SystemPrompt> getSystemPrompts() => [];

  @override
  Map<String, dynamic> getExportableSettings() => {};
}
// Actually, I don't need to override `_chatSessionToJson` if I just rely on the base class implementation.
// The base class implementation just converts the object to a map. It should be fine.

void main() {
  group('StorageService Export Tests', () {
    late TestStorageService service;
    late List<ChatSession> sessions;

    setUp(() {
      sessions = [
        ChatSession(
          id: '1',
          title: 'Chat 1',
          model: 'llama3',
          messages: [
            ChatMessage(
              role: 'user',
              content: 'Hello',
              timestamp: DateTime.now(),
            )
          ],
          createdAt: DateTime.now(),
        ),
        ChatSession(
          id: '2',
          title: 'Chat 2',
          model: 'mistral',
          messages: [],
          createdAt: DateTime.now(),
        ),
        ChatSession(
          id: '3',
          title: 'Chat 3',
          model: 'phi',
          messages: [],
          createdAt: DateTime.now(),
        ),
      ];
      service = TestStorageService(sessions);
    });

    test('exportData filters by chatIds', () {
      final result = service.exportData(chatIds: ['1', '3']);
      final exportedChats = result['chats'] as List;

      expect(exportedChats.length, 2);
      expect(exportedChats.any((c) => c['id'] == '1'), true);
      expect(exportedChats.any((c) => c['id'] == '3'), true);
      expect(exportedChats.any((c) => c['id'] == '2'), false);
    });

    test('exportData includes all if chatIds is null', () {
      final result = service.exportData(chatIds: null);
      final exportedChats = result['chats'] as List;

      expect(exportedChats.length, 3);
    });

    test('exportToCsv filters by chatIds', () {
      final result = service.exportToCsv(chatIds: ['2']);

      expect(result.contains('Chat 2'), true);
      expect(result.contains('Chat 1'), false);
      expect(result.contains('Chat 3'), false);
    });

    test('exportToMarkdown filters by chatIds', () {
      final result = service.exportToMarkdown(chatIds: ['1']);

      expect(result.contains('## Chat 1'), true);
      expect(result.contains('## Chat 2'), false);
      expect(result.contains('## Chat 3'), false);
    });
  });
}
