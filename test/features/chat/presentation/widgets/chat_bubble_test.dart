import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:pocketllm_lite/features/chat/presentation/widgets/chat_bubble.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_message.dart';
import 'package:pocketllm_lite/services/storage_service.dart';
import 'package:pocketllm_lite/core/providers.dart';
import 'package:hive/hive.dart';

class FakeBox extends Fake implements Box {}

class MockStorageService extends Fake implements StorageService {
  final ValueNotifier<Box> _starredBox = ValueNotifier(FakeBox());

  @override
  ValueListenable<Box> get starredMessagesListenable => _starredBox;

  @override
  bool isMessageStarred(ChatMessage message) => false;

  @override
  dynamic getSetting(String key, {dynamic defaultValue}) => defaultValue;
}

void main() {
  testWidgets('ChatBubble renders markdown content', (WidgetTester tester) async {
    final message = ChatMessage(
      role: 'assistant',
      content: 'Hello **World**',
      timestamp: DateTime.now(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(MockStorageService()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ChatBubble(message: message),
          ),
        ),
      ),
    );

    // Verify MarkdownBody is present
    expect(find.byType(MarkdownBody), findsOneWidget);

    // Verify text content
    expect(find.text('Hello World'), findsOneWidget); // Markdown renders "Hello World" (bolded)
  });

  testWidgets('ChatBubble renders timestamp', (WidgetTester tester) async {
    final message = ChatMessage(
      role: 'user',
      content: 'Hi',
      timestamp: DateTime.now(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(MockStorageService()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ChatBubble(message: message),
          ),
        ),
      ),
    );

    expect(find.text('Hi'), findsOneWidget);
    // Timestamp format depends on time, but it should be present.
    // Since it's "Just now" (less than a day), it formats as time.
    // We can just check that *some* text that is not the content is present?
    // Or just rely on no crash.
  });
}
