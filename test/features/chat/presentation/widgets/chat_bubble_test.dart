import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pocketllm_lite/features/chat/presentation/widgets/chat_bubble.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_message.dart';
import 'package:pocketllm_lite/services/storage_service.dart';
import 'package:pocketllm_lite/core/providers.dart';
import 'package:flutter/foundation.dart';

class FakeBox extends Fake implements Box {}

class MockStorageService extends Fake implements StorageService {
  final ValueNotifier<Box> _starredBox = ValueNotifier(FakeBox());
  bool _isStarred = false;

  void setStarred(bool value) {
    _isStarred = value;
    // Trigger update by setting a new FakeBox
    _starredBox.value = FakeBox();
  }

  @override
  ValueListenable<Box> get starredMessagesListenable => _starredBox;

  @override
  bool isMessageStarred(ChatMessage message) {
    return _isStarred;
  }

  @override
  dynamic getSetting(String key, {dynamic defaultValue}) {
    // Return sensible defaults for appearance settings
    // We can rely on the default values provided by the AppearanceNotifier
    // if we return null, but AppearanceNotifier expects some defaults.
    // However, AppearanceNotifier uses `defaultValue` in its `getSetting` calls.
    // So if we return `defaultValue` (which is passed in), it should work!
    return defaultValue;
  }
}

void main() {
  testWidgets('ChatBubble renders and updates star icon correctly', (WidgetTester tester) async {
    final mockStorage = MockStorageService();
    final message = ChatMessage(
      role: 'user',
      content: 'Hello',
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

    // Initial state: not starred
    expect(find.byIcon(Icons.star), findsNothing);

    // Star the message
    mockStorage.setStarred(true);
    await tester.pump(); // Rebuild

    // Should see star
    expect(find.byIcon(Icons.star), findsOneWidget);

    // Unstar
    mockStorage.setStarred(false);
    await tester.pump();

    expect(find.byIcon(Icons.star), findsNothing);
  });
}
