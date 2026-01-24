import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mockito/mockito.dart';
import 'package:pocketllm_lite/core/providers.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_message.dart';
import 'package:pocketllm_lite/features/chat/presentation/widgets/chat_bubble.dart';
import 'package:pocketllm_lite/services/storage_service.dart';
import 'package:pocketllm_lite/features/settings/presentation/providers/appearance_provider.dart';

class MockStorageService extends Mock implements StorageService {
  final ValueNotifier<Box> _starredMessagesListenable = ValueNotifier(MockBox());

  @override
  ValueListenable<Box> get starredMessagesListenable => _starredMessagesListenable;

  @override
  bool isMessageStarred(ChatMessage message) => false;
}

class MockBox extends Mock implements Box {
  @override
  bool get isEmpty => true;
  @override
  bool get isNotEmpty => false;
}

// Mock AppearanceNotifier
class MockAppearanceNotifier extends AppearanceNotifier {
  @override
  AppearanceState build() {
    return AppearanceState(
      userMsgColor: 0xFF000000,
      aiMsgColor: 0xFFFFFFFF,
      bubbleRadius: 16.0,
      fontSize: 14.0,
    );
  }
}

void main() {
  testWidgets('ChatBubble rebuilds entire body when starred messages change', (WidgetTester tester) async {
    final mockStorage = MockStorageService();

    final container = ProviderContainer(
      overrides: [
        storageServiceProvider.overrideWithValue(mockStorage),
        appearanceProvider.overrideWith(() => MockAppearanceNotifier()),
      ],
    );

    final message = ChatMessage(
      role: 'assistant',
      content: 'Hello **World**',
      timestamp: DateTime.now(),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: ChatBubble(message: message),
          ),
        ),
      ),
    );

    // Verify MarkdownBody is present
    expect(find.byType(MarkdownBody), findsOneWidget);

    // Verify MarkdownBody is a descendant of ValueListenableBuilder<Box>
    // This confirms the current (inefficient) behavior where the whole bubble is wrapped
    final markdownFinder = find.byType(MarkdownBody);
    final listenerFinder = find.byWidgetPredicate(
      (widget) => widget is ValueListenableBuilder<Box>,
    );

    expect(
      find.descendant(of: listenerFinder, matching: markdownFinder),
      findsNothing,
      reason: 'MarkdownBody should NOT be inside ValueListenableBuilder after optimization',
    );
  });
}
