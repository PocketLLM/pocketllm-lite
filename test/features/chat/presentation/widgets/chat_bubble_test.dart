import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:pocketllm_lite/features/chat/presentation/widgets/chat_bubble.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_message.dart';
import 'package:pocketllm_lite/core/providers.dart';
import 'package:pocketllm_lite/services/storage_service.dart';
import 'package:pocketllm_lite/features/settings/presentation/providers/appearance_provider.dart';

// Fake Box for Hive
class FakeBox extends Fake implements Box {
  @override
  bool get isOpen => true;
}

// Mock StorageService
class MockStorageService extends Fake implements StorageService {
  @override
  ValueListenable<Box> get starredMessagesListenable => ValueNotifier(FakeBox());

  @override
  bool isMessageStarred(ChatMessage message) => false;

  @override
  dynamic getSetting(String key, {dynamic defaultValue}) => defaultValue;
}

class MockAppearanceNotifier extends AppearanceNotifier {
  @override
  AppearanceState build() {
    return AppearanceState(
      userMsgColor: 0xFF000000,
      aiMsgColor: 0xFF000000,
      bubbleRadius: 10,
      fontSize: 14,
    );
  }
}

void main() {
  testWidgets('ChatBubble renders user message correctly', (WidgetTester tester) async {
    final message = ChatMessage(
      role: 'user',
      content: 'Hello, World!',
      timestamp: DateTime.now(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(MockStorageService()),
          appearanceProvider.overrideWith(MockAppearanceNotifier.new),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ChatBubble(message: message),
          ),
        ),
      ),
    );

    expect(find.text('Hello, World!'), findsOneWidget);
    expect(find.byType(ChatBubble), findsOneWidget);
  });

  testWidgets('ChatBubble renders assistant message correctly', (WidgetTester tester) async {
    final message = ChatMessage(
      role: 'assistant',
      content: 'Hello from AI',
      timestamp: DateTime.now(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(MockStorageService()),
          appearanceProvider.overrideWith(MockAppearanceNotifier.new),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ChatBubble(message: message),
          ),
        ),
      ),
    );

    expect(find.text('Hello from AI'), findsOneWidget);
    expect(find.byType(ChatBubble), findsOneWidget);
  });
}
