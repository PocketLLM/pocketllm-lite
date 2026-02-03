import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_message.dart';
import 'package:pocketllm_lite/features/chat/presentation/widgets/starred_message_builder.dart';
import 'package:pocketllm_lite/core/providers.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

// ignore: must_be_immutable
class FakeBox extends Box {
  @override
  dynamic noSuchMethod(Invocation invocation) => null; // Returns null/void for everything
}

class MockListenable extends ValueNotifier<Box> {
  MockListenable() : super(FakeBox());

  void trigger() {
    // Force notification by notifying listeners directly
    // ValueNotifier doesn't expose notifyListeners publicly, but we are extending it.
    notifyListeners();
  }
}

class MockStorageService extends StorageService {
  final MockListenable _mockListenable = MockListenable();
  final Map<ChatMessage, bool> _starredStatus = {};

  @override
  ValueListenable<Box> get starredMessagesListenable => _mockListenable;

  @override
  bool isMessageStarred(ChatMessage message) {
    return _starredStatus[message] ?? false;
  }

  void setStarred(ChatMessage message, bool isStarred) {
    _starredStatus[message] = isStarred;
  }

  void triggerChange() {
    _mockListenable.trigger();
  }

  @override
  Future<void> init() async {}
}

void main() {
  testWidgets('StarredMessageBuilder rebuilds only when specific message status changes', (WidgetTester tester) async {
    final mockStorage = MockStorageService();

    final message1 = ChatMessage(role: 'user', content: 'msg1', timestamp: DateTime.now());
    final message2 = ChatMessage(role: 'user', content: 'msg2', timestamp: DateTime.now());

    mockStorage.setStarred(message1, false);
    mockStorage.setStarred(message2, false);

    int buildCount = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(mockStorage),
        ],
        child: MaterialApp(
          home: StarredMessageBuilder(
            message: message1,
            builder: (context, isStarred) {
              buildCount++;
              return Text('IsStarred: $isStarred');
            },
          ),
        ),
      ),
    );

    // Initial build
    expect(buildCount, 1);
    expect(find.text('IsStarred: false'), findsOneWidget);

    // 1. Trigger update that doesn't affect message1 (e.g. message2 starred)
    // This simulates the Hive box updating due to another key/item changing.
    mockStorage.setStarred(message2, true);
    mockStorage.triggerChange(); // fires listener
    await tester.pump();

    // Verify buildCount did NOT increase (optimization works)
    // If we used ValueListenableBuilder on the whole box, this would have rebuilt.
    expect(buildCount, 1);
    expect(find.text('IsStarred: false'), findsOneWidget);

    // 2. Trigger update that affects message1
    mockStorage.setStarred(message1, true);
    mockStorage.triggerChange();
    await tester.pump();

    // Verify buildCount increased because state changed
    expect(buildCount, 2);
    expect(find.text('IsStarred: true'), findsOneWidget);

    // 3. Trigger another unrelated update
    mockStorage.setStarred(message2, false);
    mockStorage.triggerChange();
    await tester.pump();

    // Verify stable
    expect(buildCount, 2);
  });
}
