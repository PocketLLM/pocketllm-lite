import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pocketllm_lite/core/providers.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_message.dart';
import 'package:pocketllm_lite/features/chat/presentation/widgets/chat_bubble.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

// Create a Fake Box because we can't easily mock Hive Box
class FakeBox<T> extends Fake implements Box<T> {}

class MockStorageService extends StorageService {
  final ValueNotifier<Box> _mockListenable = ValueNotifier<Box>(FakeBox());
  final Set<ChatMessage> _starredMessages = {};

  @override
  ValueListenable<Box> get starredMessagesListenable => _mockListenable;

  @override
  bool isMessageStarred(ChatMessage message) {
    return _starredMessages.contains(message);
  }

  @override
  dynamic getSetting(String key, {dynamic defaultValue}) {
    return defaultValue;
  }

  // Method to simulate toggling star for testing purposes
  void toggleStarForTest(ChatMessage message) {
    if (_starredMessages.contains(message)) {
      _starredMessages.remove(message);
    } else {
      _starredMessages.add(message);
    }
    // Notify listeners by setting a new value
    _mockListenable.value = FakeBox();
  }
}

void main() {
  testWidgets('ChatBubble renders content and updates star status without rebuilding content', (
    WidgetTester tester,
  ) async {
    final mockStorage = MockStorageService();
    final message = ChatMessage(
      role: 'user',
      content: 'Hello World',
      timestamp: DateTime.now(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [storageServiceProvider.overrideWithValue(mockStorage)],
        child: MaterialApp(
          home: Scaffold(body: ChatBubble(message: message)),
        ),
      ),
    );

    // Verify content is rendered
    expect(find.text('Hello World'), findsOneWidget);

    // Initial state: not starred
    expect(find.byIcon(Icons.star), findsNothing);

    // Toggle star via mock
    mockStorage.toggleStarForTest(message);
    await tester.pump(); // Trigger rebuild via ValueListenable

    // Verify star icon is present
    expect(find.byIcon(Icons.star), findsOneWidget);

    // Verify content is still there
    expect(find.text('Hello World'), findsOneWidget);
  });
}
