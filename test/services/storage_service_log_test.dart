import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_session.dart';
import 'package:pocketllm_lite/features/chat/domain/models/system_prompt.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

class MockStorageService extends StorageService {
  final List<Map<String, dynamic>> logs = [];
  final List<ChatSession> mockSessions = [];
  final List<SystemPrompt> mockPrompts = [];
  final List<Map<String, dynamic>> activityLogs = [
    {
      'timestamp': '2025-05-24T10:00:00.000',
      'action': 'Chat Created',
      'details': 'Created new chat',
    },
    {
      'timestamp': '2025-05-24T10:05:00.000',
      'action': 'Settings Changed',
      'details': 'Updated theme',
    },
  ];

  @override
  Future<void> logActivity(String action, String details) async {
    logs.add({'action': action, 'details': details});
  }

  @override
  List<ChatSession> getChatSessions() => mockSessions;

  @override
  List<SystemPrompt> getSystemPrompts() => mockPrompts;

  @override
  List<Map<String, dynamic>> getActivityLogs() => activityLogs;
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

    test('exportActivityLogsToCsv logs activity and returns correct format', () {
      final csv = storage.exportActivityLogsToCsv();
      expect(storage.logs.length, 1);
      expect(storage.logs.first['action'], 'Data Export');
      expect(storage.logs.first['details'], contains('activity logs as CSV'));

      expect(csv, contains('Timestamp,Action,Details'));
      expect(csv, contains('Chat Created'));
      expect(csv, contains('Settings Changed'));
    });

    test('exportActivityLogsToJson logs activity and returns correct format', () {
      final json = storage.exportActivityLogsToJson();
      expect(storage.logs.length, 1);
      expect(storage.logs.first['action'], 'Data Export');
      expect(storage.logs.first['details'], contains('activity logs as JSON'));

      expect(json, contains('"action": "Chat Created"'));
      expect(json, contains('"action": "Settings Changed"'));
    });

    test('searchActivityLogs returns all logs when query and filter are empty', () {
      final results = storage.searchActivityLogs();
      expect(results.length, 2);
    });

    test('searchActivityLogs filters by query', () {
      final results = storage.searchActivityLogs(query: 'theme');
      expect(results.length, 1);
      expect(results.first['action'], 'Settings Changed');
    });

    test('searchActivityLogs filters by category (chats)', () {
      final results = storage.searchActivityLogs(filter: 'chats');
      expect(results.length, 1);
      expect(results.first['action'], 'Chat Created');
    });

    test('searchActivityLogs filters by category (settings)', () {
      final results = storage.searchActivityLogs(filter: 'settings');
      expect(results.length, 1);
      expect(results.first['action'], 'Settings Changed');
    });

    test('searchActivityLogs filters by both query and category', () {
      // Should find nothing if query matches but category doesn't
      var results = storage.searchActivityLogs(query: 'theme', filter: 'chats');
      expect(results.isEmpty, true);

      // Should find if both match
      results = storage.searchActivityLogs(query: 'theme', filter: 'settings');
      expect(results.length, 1);
    });
  });
}
