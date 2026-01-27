import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_message.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_session.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

class TestStorageService extends StorageService {
  final List<ChatSession> _sessions;

  TestStorageService(this._sessions);

  @override
  List<ChatSession> getChatSessions() {
    return _sessions;
  }

  @override
  Future<void> logActivity(String action, String details) async {
    // No-op
  }
}

void main() {
  test('Markdown export sanitizes title, model and system prompt', () async {
    final session = ChatSession(
      id: '1',
      title: 'My Title\n# Hacked Title',
      model: 'llama3\n# Hacked Model',
      messages: [
        ChatMessage(
          role: 'user',
          content: 'Hello',
          timestamp: DateTime.now(),
        ),
      ],
      createdAt: DateTime.now(),
      systemPrompt: 'You are a helper.\n# Hacked System Prompt',
    );

    final service = TestStorageService([session]);
    final markdown = service.exportToMarkdown();

    // Check Title Sanitization
    expect(markdown.contains('## My Title\n# Hacked Title'), isFalse, reason: 'Title should not contain injected newline+header');
    expect(markdown.contains('## My Title # Hacked Title'), isTrue, reason: 'Title newlines should be replaced with space');

    // Check Model Sanitization
    expect(markdown.contains('**Model:** llama3\n# Hacked Model'), isFalse, reason: 'Model should not contain injected newline');

    // Check System Prompt Sanitization
    expect(markdown.contains('\n> # Hacked System Prompt'), isTrue, reason: 'System prompt lines should be quoted');
    expect(markdown.contains('\n# Hacked System Prompt'), isFalse, reason: 'System prompt should not leak unquoted lines');
  });

  test('Markdown export sanitizes message content', () {
    final session = ChatSession(
      id: '2',
      title: 'Safe Title',
      model: 'Safe Model',
      messages: [
        ChatMessage(
          role: 'user',
          content: 'Line 1\n# Hacked Message',
          timestamp: DateTime.now(),
        ),
      ],
      createdAt: DateTime.now(),
    );

    final service = TestStorageService([session]);
    final markdown = service.exportToMarkdown();

    // Verify message content is quoted
    expect(markdown.contains('> Line 1'), isTrue, reason: 'First line should be quoted');
    expect(markdown.contains('> # Hacked Message'), isTrue, reason: 'Second line should be quoted');

    // Ensure the header injection didn't succeed
    // We check that "# Hacked Message" is NOT present as a header (start of line)
    // The previous check ensures it IS present as a quote.
    // So we just check for the unquoted version.
    expect(markdown.contains('\n# Hacked Message'), isFalse, reason: 'Message content should not leak unquoted headers');
  });
}
