import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mockito/mockito.dart';
import 'package:pocketllm_lite/core/providers.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_message.dart';
import 'package:pocketllm_lite/features/chat/presentation/widgets/chat_bubble.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

// Mock StorageService
class MockStorageService extends Fake implements StorageService {
  final ValueNotifier<Box> starredListenable;

  MockStorageService({ValueNotifier<Box>? starredListenable})
      : starredListenable = starredListenable ?? ValueNotifier<Box>(FakeBox());

  @override
  ValueListenable<Box> get starredMessagesListenable => starredListenable;

  @override
  bool isMessageStarred(ChatMessage message) {
    return false;
  }

  @override
  dynamic getSetting(String key, {dynamic defaultValue}) {
    return defaultValue;
  }
}

class FakeBox extends Fake implements Box {
  @override
  bool get isOpen => true;

  @override
  dynamic get(key, {defaultValue}) => defaultValue;
}

void main() {
  testWidgets('ChatBubble renders correctly and handles storage updates', (WidgetTester tester) async {
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
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ChatBubble(message: message),
          ),
        ),
      ),
    );

    // Initial render check
    expect(find.text('Hello World'), findsOneWidget);

    // Trigger update
    mockStorage.starredListenable.notifyListeners();
    await tester.pump();

    // Verify it still renders correctly after update
    expect(find.text('Hello World'), findsOneWidget);
  });
}
