import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketllm_lite/features/chat/presentation/widgets/chat_bubble.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_message.dart';
import 'package:pocketllm_lite/services/storage_service.dart';
import 'package:pocketllm_lite/core/providers.dart';
import 'package:hive/hive.dart';

class MockBox extends Fake implements Box {}

// Mock StorageService
class MockStorageService extends StorageService {
  final ValueNotifier<Box> starredNotifier = ValueNotifier(MockBox());
  // Helper to simulate starred list for isMessageStarred
  final Set<ChatMessage> _starredMessages = {};

  @override
  ValueListenable<Box> get starredMessagesListenable => starredNotifier;

  @override
  bool isMessageStarred(ChatMessage message) {
    return _starredMessages.contains(message);
  }

  @override
  dynamic getSetting(String key, {dynamic defaultValue}) {
    return defaultValue;
  }
}

void main() {
  testWidgets('ChatBubble renders correctly and updates star icon', (WidgetTester tester) async {
    final message = ChatMessage(
      role: 'user',
      content: 'Hello World',
      timestamp: DateTime.now(),
    );

    final mockStorage = MockStorageService();

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

    // Verify content
    expect(find.text('Hello World'), findsOneWidget);
    // Verify star icon is NOT present initially
    expect(find.byIcon(Icons.star), findsNothing);

    // Star the message
    mockStorage._starredMessages.add(message);
    // Trigger update by setting value to new MockBox
    mockStorage.starredNotifier.value = MockBox();
    await tester.pump(); // Rebuild listeners

    // Verify star icon IS present
    expect(find.byIcon(Icons.star), findsOneWidget);

    // Unstar
    mockStorage._starredMessages.remove(message);
    mockStorage.starredNotifier.value = MockBox();
    await tester.pump();

    // Verify star icon is GONE
    expect(find.byIcon(Icons.star), findsNothing);
  });
}
