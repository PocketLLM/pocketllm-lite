import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_session.dart';
import 'package:pocketllm_lite/features/chat/domain/models/system_prompt.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

class MockStorageService extends StorageService {
  final List<Map<String, dynamic>> logs = [];
  final List<ChatSession> mockSessions = [];
  final List<SystemPrompt> mockPrompts = [];

  @override
  Future<void> logActivity(String action, String details) async {
    logs.add({'action': action, 'details': details});
  }

  @override
  List<ChatSession> getChatSessions() => mockSessions;

  @override
  List<SystemPrompt> getSystemPrompts() => mockPrompts;
}

void main() {
  group('StorageService Activity Logging', () {
    late MockStorageService storage;

    setUp(() {
      storage = MockStorageService();
    });

    test('exportData logs activity', () {
      storage.exportData();
      expect(storage.logs.length, 1);
      expect(storage.logs.first['action'], 'Data Export');
      expect(storage.logs.first['details'], contains('Chats: true'));
    });

    test('exportToCsv logs activity', () {
      storage.exportToCsv();
      expect(storage.logs.length, 1);
      expect(storage.logs.first['action'], 'Data Export');
      expect(storage.logs.first['details'], contains('CSV'));
    });

    test('exportToMarkdown logs activity', () {
      storage.exportToMarkdown();
      expect(storage.logs.length, 1);
      expect(storage.logs.first['action'], 'Data Export');
      expect(storage.logs.first['details'], contains('Markdown'));
    });
  });
}
