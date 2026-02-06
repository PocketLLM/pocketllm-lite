import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pocketllm_lite/features/chat/presentation/widgets/chat_bubble.dart';
import 'package:pocketllm_lite/core/providers.dart';
import 'package:pocketllm_lite/services/storage_service.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_message.dart';
import 'package:pocketllm_lite/features/settings/presentation/providers/appearance_provider.dart';
import 'package:pocketllm_lite/features/profile/presentation/providers/profile_provider.dart';

// Mock Box
class FakeBox extends Fake implements Box {
  @override
  bool get isOpen => true;
}

// Mock StorageService
class MockStorageService extends Fake implements StorageService {
  final ValueNotifier<Box> _starredNotifier = ValueNotifier<Box>(FakeBox());

  @override
  ValueListenable<Box> get starredMessagesListenable => _starredNotifier;

  bool _isStarred = false;

  @override
  bool isMessageStarred(ChatMessage message) => _isStarred;

  void setStarred(bool value) {
    _isStarred = value;
    _starredNotifier.value = FakeBox();
  }

  @override
  dynamic getSetting(String key, {dynamic defaultValue}) {
    return defaultValue;
  }
}

class MockAppearanceNotifier extends AppearanceNotifier {
  MockAppearanceNotifier() : super();
}

class MockProfileNotifier extends ProfileNotifier {
  MockProfileNotifier() : super();
}

void main() {
  testWidgets('ChatBubble shows star icon when message is starred', (WidgetTester tester) async {
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
          appearanceProvider.overrideWith(MockAppearanceNotifier.new),
          profileProvider.overrideWith(MockProfileNotifier.new),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ChatBubble(message: message),
          ),
        ),
      ),
    );

    // Initially not starred
    expect(find.byIcon(Icons.star), findsNothing);

    // Toggle star
    mockStorage.setStarred(true);
    await tester.pumpAndSettle();

    // Should be starred
    expect(find.byIcon(Icons.star), findsOneWidget);

    // Toggle back
    mockStorage.setStarred(false);
    await tester.pumpAndSettle();

    // Should not be starred
    expect(find.byIcon(Icons.star), findsNothing);
  });
}
