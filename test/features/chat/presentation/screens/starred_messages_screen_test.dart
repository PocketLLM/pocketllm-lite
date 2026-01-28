import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/features/chat/presentation/screens/starred_messages_screen.dart';
import 'package:pocketllm_lite/services/storage_service.dart';
import 'package:pocketllm_lite/core/providers.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter/foundation.dart';
import 'package:pocketllm_lite/features/chat/domain/models/starred_message.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_message.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_session.dart';

// Create a Fake Box because mocking generics with Mockito is sometimes tricky
// and we just need a ValueListenable that emits changes.
class FakeBox extends Fake implements Box {}

class MockStorageService extends Mock implements StorageService {
  final ValueNotifier<Box> _settingsBoxNotifier = ValueNotifier(FakeBox());
  final ValueNotifier<Box> _starredMessagesNotifier = ValueNotifier(FakeBox());

  // We track access to verified correct usage
  bool settingsBoxListenableAccessed = false;
  bool starredMessagesListenableAccessed = false;

  @override
  ValueListenable<Box> get settingsBoxListenable {
    settingsBoxListenableAccessed = true;
    return _settingsBoxNotifier;
  }

  @override
  ValueListenable<Box> get starredMessagesListenable {
    starredMessagesListenableAccessed = true;
    return _starredMessagesNotifier;
  }

  @override
  List<StarredMessage> getStarredMessages() {
    return [
      StarredMessage(
        id: '1',
        chatId: 'chat1',
        message: ChatMessage(
          role: 'user',
          content: 'Test message',
          timestamp: DateTime.now(),
        ),
        starredAt: DateTime.now(),
      ),
    ];
  }

  @override
  ChatSession? getChatSession(String id) {
    return ChatSession(
      id: 'chat1',
      title: 'Test Chat',
      model: 'llama3',
      messages: [],
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<void> unstarMessage(String id) async {}
}

void main() {
  testWidgets('StarredMessagesScreen should use scoped starredMessagesListenable', (WidgetTester tester) async {
    final mockStorage = MockStorageService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(mockStorage),
        ],
        child: const MaterialApp(
          home: StarredMessagesScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify that the screen renders
    expect(find.text('Starred Messages'), findsOneWidget);
    expect(find.text('Test message'), findsOneWidget);

    // Verify correct listenable is used
    expect(mockStorage.starredMessagesListenableAccessed, isTrue, reason: 'Should access starredMessagesListenable');
    expect(mockStorage.settingsBoxListenableAccessed, isFalse, reason: 'Should NOT access settingsBoxListenable');
  });
}
