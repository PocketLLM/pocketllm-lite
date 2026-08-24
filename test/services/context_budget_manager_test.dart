import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_message.dart';
import 'package:pocketllm_lite/services/context_budget_manager.dart';

void main() {
  late ContextBudgetManager manager;

  setUp(() {
    manager = ContextBudgetManager();
  });

  test('token estimator returns proportional count', () {
    final tokens =
        manager.estimateTokens('Hello world! This is a test prompt.');
    expect(tokens, greaterThan(0));
    expect(tokens, lessThan(30));
  });

  test('context fit retains all messages when within budget', () {
    final messages = [
      ChatMessage(role: 'user', content: 'Hi', timestamp: DateTime.now()),
      ChatMessage(
          role: 'assistant', content: 'Hello!', timestamp: DateTime.now()),
    ];

    final result = manager.fitContext(
      messages: messages,
      maxContextTokens: 8192,
      systemPrompt: 'You are a helpful assistant',
    );

    expect(result.wasSummarized, isFalse);
    expect(result.fittedMessages.length, equals(2));
  });

  test('context overflow triggers local summarization', () {
    final longTurnText = 'A ' * 2000;
    final messages = List.generate(
      10,
      (index) => ChatMessage(
        role: index % 2 == 0 ? 'user' : 'assistant',
        content: 'Turn $index: $longTurnText',
        timestamp: DateTime.now(),
      ),
    );

    final result = manager.fitContext(
      messages: messages,
      maxContextTokens: 2048,
      systemPrompt: 'You are an AI assistant',
    );

    expect(result.wasSummarized, isTrue);
    expect(result.summaryNotice, contains('summarized locally'));
    expect(result.fittedMessages.first.role, equals('system'));
  });
}
