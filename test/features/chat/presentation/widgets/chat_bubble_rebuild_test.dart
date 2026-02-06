import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pocketllm_lite/core/providers.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_message.dart';
import 'package:pocketllm_lite/features/chat/presentation/widgets/chat_bubble.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

// Mock Box using Fake
class MockBox extends Fake implements Box {}

class MockStorageService extends Fake implements StorageService {
  final ValueNotifier<Box> _starredNotifier = ValueNotifier(MockBox());
  final Set<ChatMessage> _starredMessages = {};

  @override
  ValueListenable<Box> get starredMessagesListenable => _starredNotifier;

  @override
  bool isMessageStarred(ChatMessage message) {
    return _starredMessages.contains(message);
  }

  // Helper to simulate external change
  void toggleStar(ChatMessage message) {
    if (_starredMessages.contains(message)) {
      _starredMessages.remove(message);
    } else {
      _starredMessages.add(message);
    }
    // Notify listeners
    // We create a new MockBox to ensure the value effectively "changes"
    // if the listener checks for identity, though ValueNotifier notifies on assignment usually.
    // Actually ValueNotifier only notifies if value != old value.
    _starredNotifier.value = MockBox();
  }

  @override
  dynamic getSetting(String key, {dynamic defaultValue}) {
    return defaultValue;
  }
}

void main() {
  testWidgets('ChatBubble updates star icon when storage changes', (tester) async {
    final message = ChatMessage(
      role: 'assistant',
      content: 'Hello',
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

    // Initial state: Not starred
    expect(find.byIcon(Icons.star), findsNothing);

    // Act: Star the message
    mockStorage.toggleStar(message);
    await tester.pumpAndSettle(); // Process the notification and rebuilds

    // Assert: Star is visible
    expect(find.byIcon(Icons.star), findsOneWidget);

    // Act: Unstar
    mockStorage.toggleStar(message);
    await tester.pumpAndSettle();

    // Assert: Star is gone
    expect(find.byIcon(Icons.star), findsNothing);
  });
}
