import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_session.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

class TestStorageService extends StorageService {
  final List<ChatSession> testSessions;

  TestStorageService(this.testSessions);

  @override
  List<ChatSession> getChatSessions() {
    return testSessions;
  }

  @override
  Future<void> logActivity(String action, String details) async {
    // Mock logging to avoid Hive dependency
    return;
  }
}

void main() {
  group('CSV Injection Security', () {
    test('Should escape fields starting with dangerous characters', () {
      final maliciousSession = ChatSession(
        id: '1',
        title: '=cmd| /C calc',
        model: 'gpt-4',
        messages: [],
        createdAt: DateTime(2023, 1, 1),
        systemPrompt: '+malicious_prompt',
      );

      final service = TestStorageService([maliciousSession]);
      final csv = service.exportToCsv();

      // The title should be escaped with a single quote
      expect(csv, contains("'=cmd| /C calc"));
      expect(csv, contains("'+malicious_prompt"));
    });

    test('Should escape fields starting with Tab and Carriage Return', () {
      final maliciousSession = ChatSession(
        id: '2',
        title: '\tmalicious_tab',
        model: 'model',
        messages: [],
        createdAt: DateTime(2023, 1, 1),
        systemPrompt: '\rmalicious_cr',
      );

      final service = TestStorageService([maliciousSession]);
      final csv = service.exportToCsv();

      expect(csv, contains("'\tmalicious_tab"));
      expect(csv, contains("'\rmalicious_cr"));
    });

    test(
      'Should escape fields starting with whitespace and dangerous characters',
      () {
        final maliciousSession = ChatSession(
          id: '3',
          title: '   =cmd',
          model: 'model',
          messages: [],
          createdAt: DateTime(2023, 1, 1),
          systemPrompt: '\t=cmd',
        );

        final service = TestStorageService([maliciousSession]);
        final csv = service.exportToCsv();

        expect(csv, contains("'   =cmd"));
        expect(
          csv,
          contains("'\t=cmd"),
        ); // \t is both whitespace (for trim) and dangerous char
      },
    );
  });
}
