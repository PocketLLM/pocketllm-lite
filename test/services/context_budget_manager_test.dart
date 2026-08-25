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

  test('context overflow uses a real injected local summary', () async {
    final longTurnText = 'A ' * 2000;
    final messages = List.generate(
      10,
      (index) => ChatMessage(
        role: index % 2 == 0 ? 'user' : 'assistant',
        content: 'Turn $index: $longTurnText',
        timestamp: DateTime.now(),
      ),
    );

    final result = await manager.fitContextWithSummary(
      messages: messages,
      maxContextTokens: 2048,
      systemPrompt: 'You are an AI assistant',
      summarizer: (older, previous) async =>
          '{"facts":["Ten long test turns"],"unresolved_questions":[],"decisions":[],"references":[],"task_state":[]}',
    );

    expect(result.wasSummarized, isTrue);
    expect(result.summaryNotice, contains('summarized locally'));
    expect(result.fittedMessages.first.role, equals('system'));
    expect(result.rollingSummary, contains('Ten long test turns'));
  });

  test('overflow never invents a substring summary', () {
    final messages = List.generate(
      12,
      (index) => ChatMessage(
        role: index.isEven ? 'user' : 'assistant',
        content: 'Turn $index ${'long content ' * 100}',
        timestamp: DateTime.now(),
      ),
    );
    final result = manager.fitContext(
      messages: messages,
      maxContextTokens: 512,
    );
    expect(result.wasSummarized, isFalse);
    expect(result.summaryNotice, contains('no verified rolling summary'));
    expect(result.omittedMessageCount, greaterThan(0));
    expect(
      result.fittedMessages.any((message) => message.content.contains('...')),
      isFalse,
    );
  });

  test('oversized newest message fails instead of silently dropping it', () {
    final messages = [
      ChatMessage(
        role: 'user',
        content: 'important ' * 1000,
        timestamp: DateTime.now(),
      ),
    ];

    expect(
      () => manager.fitContext(
        messages: messages,
        maxContextTokens: 512,
      ),
      throwsA(
        isA<ContextWindowError>().having(
          (error) => error.message,
          'message',
          contains('newest message'),
        ),
      ),
    );
  });

  test('reserves the caller requested output budget', () {
    final result = manager.fitContext(
      messages: [
        ChatMessage(
          role: 'user',
          content: 'A short prompt',
          timestamp: DateTime.utc(2026),
        ),
      ],
      maxContextTokens: 2048,
      responseReservationTokens: 1024,
    );

    expect(result.remainingBudget, lessThan(1024));
  });

  test('rejects an output reservation that consumes the whole context', () {
    expect(
      () => manager.fitContext(
        messages: [
          ChatMessage(
            role: 'user',
            content: 'Hello',
            timestamp: DateTime.utc(2026),
          ),
        ],
        maxContextTokens: 2048,
        responseReservationTokens: 2048,
      ),
      throwsA(isA<ContextWindowError>()),
    );
  });
}
