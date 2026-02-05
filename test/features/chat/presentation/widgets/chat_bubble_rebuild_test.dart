import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pocketllm_lite/features/chat/presentation/widgets/chat_bubble.dart';
import 'package:pocketllm_lite/core/providers.dart';
import 'package:pocketllm_lite/services/storage_service.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_message.dart';

class MockBox extends Fake implements Box {
  @override
  bool get isOpen => true;
}

class MockBoxListenable extends ValueNotifier<Box> {
  MockBoxListenable() : super(MockBox());

  void notify() {
    notifyListeners();
  }
}

class MockStorageService extends Fake implements StorageService {
  final _listenable = MockBoxListenable();
  final Set<ChatMessage> _starredMessages = {};

  @override
  ValueListenable<Box> get starredMessagesListenable => _listenable;

  @override
  bool isMessageStarred(ChatMessage message) {
    return _starredMessages.contains(message);
  }

  void toggleStar(ChatMessage message) {
    if (_starredMessages.contains(message)) {
      _starredMessages.remove(message);
    } else {
      _starredMessages.add(message);
    }
    _listenable.notify();
  }

  @override
  dynamic getSetting(String key, {dynamic defaultValue}) {
    return defaultValue;
  }
}

void main() {
  testWidgets('ChatBubble updates star icon without full rebuild', (
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
        child: MaterialApp(home: Scaffold(body: ChatBubble(message: message))),
      ),
    );

    // Initial state: Not starred
    expect(find.byIcon(Icons.star), findsNothing);

    // Star the message
    mockStorage.toggleStar(message);
    await tester.pump(); // Rebuild triggered by ValueListenable

    // Should see star icon
    expect(find.byIcon(Icons.star), findsOneWidget);

    // Unstar
    mockStorage.toggleStar(message);
    await tester.pump();

    // Should not see star icon
    expect(find.byIcon(Icons.star), findsNothing);
  });
}
