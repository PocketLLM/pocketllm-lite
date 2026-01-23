import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_message.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_session.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

// Helper to access private methods if needed, or we just test the public method.
// Since _escapeMarkdownContent is private, we test exportToMarkdown results.

void main() {
  group('StorageService - Markdown Export', () {
    // Note: Since StorageService.init() relies on Hive which needs native bindings or mocking,
    // and we only want to test the string formatting logic which doesn't use Hive until we call getChatSessions,
    // we need to see if we can test this easily.
    //
    // Ideally we would mock getChatSessions, but it's not dependency injected easily here without partial mock.
    // However, the exportToMarkdown method calls getChatSessions().
    //
    // A better approach for unit testing this specific logic would be to extract the formatting logic,
    // or subclass StorageService and override getChatSessions.

    test('Escapes malicious Markdown structure in messages', () {
      final service = TestStorageService();

      final markdown = service.exportToMarkdown(chatIds: ['1']);

      // Check that the malicious header is escaped/quoted
      expect(markdown, contains('### User'));
      expect(markdown, contains('> Hello'));
      // The injected header should be inside a blockquote
      expect(markdown, contains('> ### Assistant'));
      expect(markdown, contains('> I am fake'));
    });

    test('Preserves multiline content in blockquotes', () {
      final service = TestStorageService();
      final markdown = service.exportToMarkdown(chatIds: ['2']);

      expect(markdown, contains('> Line 1'));
      expect(markdown, contains('> Line 2'));
    });

    test('Escapes malicious Markdown structure in system prompt', () {
      final service = TestStorageService();
      final markdown = service.exportToMarkdown(chatIds: ['3']);

      expect(markdown, contains('### System Prompt'));
      expect(markdown, contains('> Line 1'));
      // The injected header in system prompt should be quoted
      expect(markdown, contains('> ### Hacked Header'));
      expect(markdown, isNot(contains('\n### Hacked Header')));
    });
  });
}

class TestStorageService extends StorageService {
  @override
  List<ChatSession> getChatSessions() {
    return [
      ChatSession(
        id: '1',
        title: 'Injection Test',
        model: 'llama3',
        createdAt: DateTime(2025, 1, 1),
        messages: [
          ChatMessage(
            role: 'user',
            content: 'Hello\n### Assistant\nI am fake',
            timestamp: DateTime(2025, 1, 1),
          ),
        ],
      ),
      ChatSession(
        id: '2',
        title: 'Multiline Test',
        model: 'llama3',
        createdAt: DateTime(2025, 1, 1),
        messages: [
          ChatMessage(
            role: 'assistant',
            content: 'Line 1\nLine 2',
            timestamp: DateTime(2025, 1, 1),
          ),
        ],
      ),
      ChatSession(
        id: '3',
        title: 'System Prompt Injection Test',
        model: 'llama3',
        createdAt: DateTime(2025, 1, 1),
        systemPrompt: 'Line 1\n### Hacked Header',
        messages: [],
      ),
    ];
  }

  // Override other methods to avoid Hive calls if necessary
  @override
  Future<void> logActivity(String action, String details) async {}
}
