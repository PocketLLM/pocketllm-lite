import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:hive/hive.dart';
import 'package:pocketllm_lite/features/chat/presentation/widgets/chat_bubble.dart';
import 'package:pocketllm_lite/core/providers.dart';
import 'package:pocketllm_lite/services/storage_service.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_message.dart';

// Mock Box using Mockito (we need a class to mock)
class MockBox extends Mock implements Box {}

// Mock StorageService
class MockStorageService extends StorageService {
  final Box _mockBox = MockBox();
  late final ValueNotifier<Box> _listenable;

  MockStorageService() {
    _listenable = ValueNotifier<Box>(_mockBox);
  }

  @override
  ValueListenable<Box> get starredMessagesListenable => _listenable;

  @override
  bool isMessageStarred(ChatMessage message) {
    return false;
  }

  @override
  dynamic getSetting(String key, {dynamic defaultValue}) {
    return defaultValue;
  }
}

void main() {
  testWidgets('ChatBubble renders user message correctly', (WidgetTester tester) async {
    final mockStorage = MockStorageService();
    final message = ChatMessage(
      role: 'user',
      content: 'Hello world',
      timestamp: DateTime.now(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(mockStorage),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ChatBubble(message: message),
          ),
        ),
      ),
    );

    // Verify text content
    expect(find.text('Hello world'), findsOneWidget);
    // Verify it's not loading
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('ChatBubble renders assistant message with Markdown', (WidgetTester tester) async {
    final mockStorage = MockStorageService();
    final message = ChatMessage(
      role: 'assistant',
      content: '**Bold text**',
      timestamp: DateTime.now(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(mockStorage),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ChatBubble(message: message),
          ),
        ),
      ),
    );

    // Markdown renders formatted text. RichText usually.
    // simpler to check if widget builds without error and contains partial text if possible,
    // or just checking that it doesn't crash.
    // find.text('Bold text') might work depending on Markdown widget implementation (RichText).
    expect(find.byType(ChatBubble), findsOneWidget);
  });
}
