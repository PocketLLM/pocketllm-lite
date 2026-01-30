import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:pocketllm_lite/features/chat/presentation/widgets/chat_bubble.dart';
import 'package:pocketllm_lite/core/providers.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_message.dart';
import 'package:pocketllm_lite/services/storage_service.dart';
import 'package:pocketllm_lite/features/settings/presentation/providers/appearance_provider.dart';

// Mock Box
class MockBox extends Fake implements Box {}

// Mock StorageService
class MockStorageService extends Fake implements StorageService {
  final ValueNotifier<Box> _starredBoxListenable = ValueNotifier(MockBox());
  final Set<ChatMessage> _starred = {};

  @override
  ValueListenable<Box> get starredMessagesListenable => _starredBoxListenable;

  @override
  bool isMessageStarred(ChatMessage message) {
    return _starred.contains(message);
  }

  @override
  dynamic getSetting(String key, {dynamic defaultValue}) {
    return defaultValue;
  }

  void toggleMockStar(ChatMessage message) {
    if (_starred.contains(message)) {
      _starred.remove(message);
    } else {
      _starred.add(message);
    }
    // Force notification by creating new mock box instance
    _starredBoxListenable.value = MockBox();
  }
}

void main() {
  testWidgets('ChatBubble updates star icon when storage updates', (WidgetTester tester) async {
    final mockStorage = MockStorageService();
    final message = ChatMessage(
      role: 'user',
      content: 'Hello World',
      timestamp: DateTime.now(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(mockStorage),
          appearanceProvider.overrideWith(() => AppearanceNotifier()),
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
    expect(find.text('Hello World'), findsOneWidget);

    // Toggle star
    mockStorage.toggleMockStar(message);
    await tester.pump();

    // Verify star icon appears
    expect(find.byIcon(Icons.star), findsOneWidget);
    expect(find.text('Hello World'), findsOneWidget); // Content still there

    // Toggle unstar
    mockStorage.toggleMockStar(message);
    await tester.pump();

    // Verify star icon disappears
    expect(find.byIcon(Icons.star), findsNothing);
    expect(find.text('Hello World'), findsOneWidget);
  });
}
