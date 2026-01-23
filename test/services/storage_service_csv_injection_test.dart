import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_session.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_message.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

class MockStorageService extends StorageService {
  final List<ChatSession> mockSessions = [];

  @override
  List<ChatSession> getChatSessions() => mockSessions;

  @override
  Future<void> logActivity(String action, String details) async {}
}

void main() {
  group('StorageService CSV Injection Security', () {
    late MockStorageService storage;

    setUp(() {
      storage = MockStorageService();
    });

    test('exportToCsv escapes malicious formula characters', () {
      final maliciousSession = ChatSession(
        id: '1',
        title: '=1+1',
        model: 'llama3',
        createdAt: DateTime(2023, 1, 1),
        messages: [
          ChatMessage(role: 'user', content: '+2+2', timestamp: DateTime(2023, 1, 1)),
        ],
        systemPrompt: '@SUM(1,1)',
      );

      storage.mockSessions.add(maliciousSession);

      final csv = storage.exportToCsv();

      // Expected format: ID,Title,Model,Created At,Message Count,System Prompt
      // ID: 1
      // Title: '=1+1 (Escaped)
      // Model: llama3
      // ...
      // System Prompt: '@SUM(1,1) (Escaped)

      // Check Title
      expect(csv, contains(",'=1+1,"));

      // Check System Prompt (last field)
      // Since it contains a comma, it will be quoted: "'@SUM(1,1)"
      expect(csv, contains(',"\'@SUM(1,1)"'));
    });

    test('exportToCsv escapes malicious characters with quoting', () {
      final maliciousSession = ChatSession(
        id: '2',
        title: '=1,1', // Needs quoting AND escaping
        model: 'llama3',
        createdAt: DateTime(2023, 1, 1),
        messages: [],
      );

      storage.mockSessions.add(maliciousSession);
      final csv = storage.exportToCsv();

      // '=1,1 -> Escaped to `'=1,1` -> Quoted to `"'=1,1"`
      expect(csv, contains(',"\'=1,1",'));
    });
  });
}
