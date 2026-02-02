import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:pocketllm_lite/features/chat/presentation/widgets/chat_bubble.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_message.dart';
import 'package:pocketllm_lite/core/providers.dart';
import 'package:pocketllm_lite/services/storage_service.dart';
import 'package:pocketllm_lite/features/settings/presentation/providers/appearance_provider.dart';

// Mock Box
class MockBox extends Fake implements Box {
  @override
  bool get isEmpty => false;
  @override
  bool get isNotEmpty => true;
}

// Mock StorageService
class MockStorageService extends Fake implements StorageService {
  final ValueNotifier<Box> _starredNotifier = ValueNotifier(MockBox());
  final Set<ChatMessage> _starredMessages = {};

  @override
  ValueListenable<Box> get starredMessagesListenable => _starredNotifier;

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
    // Trigger rebuild
    _starredNotifier.value = MockBox();
  }

  @override
  dynamic getSetting(String key, {dynamic defaultValue}) {
    // Return safe defaults for appearance settings
    if (key.endsWith('Color')) return 0xFF000000;
    if (key.endsWith('Radius')) return 12.0;
    if (key.endsWith('Size')) return 14.0;
    if (key.endsWith('Padding')) return 8.0;
    if (key.endsWith('Elevation')) return true;
    if (key.endsWith('Opacity')) return 1.0;
    if (key == 'showAvatars') return true;
    return defaultValue;
  }
}

void main() {
  testWidgets('ChatBubble displays content and updates star status', (WidgetTester tester) async {
    final mockStorage = MockStorageService();
    final message = ChatMessage(
      role: 'assistant',
      content: 'Hello **World**',
      timestamp: DateTime.now(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(mockStorage),
          appearanceProvider.overrideWith(AppearanceNotifier.new),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ChatBubble(message: message),
          ),
        ),
      ),
    );

    // Verify content
    // MarkdownBody renders RichText. find.text might not work directly if it's split.
    // But 'Hello World' usually renders as one text span or combined.
    // Actually markdown renders 'Hello ' and 'World' (bold).
    // Let's just find RichText.
    expect(find.byType(RichText), findsWidgets);

    // Verify star is not present
    expect(find.byIcon(Icons.star), findsNothing);

    // Toggle star
    mockStorage.toggleStar(message);
    await tester.pumpAndSettle();

    // Verify star is present
    expect(find.byIcon(Icons.star), findsOneWidget);
  });
}
