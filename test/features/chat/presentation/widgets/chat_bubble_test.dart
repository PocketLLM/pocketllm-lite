import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pocketllm_lite/features/chat/presentation/widgets/chat_bubble.dart';
import 'package:pocketllm_lite/core/providers.dart';
import 'package:pocketllm_lite/services/storage_service.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_message.dart';
import 'package:pocketllm_lite/core/constants/app_constants.dart';

// Mock Box
class MockBox extends Fake implements Box {
  // Hive uses extension method for listenable, so we can't override it.
  // But StorageService calls listenable(), which on a real box calls the extension.
  // Since we are mocking StorageService, we just need to ensure starredMessagesListenable returns our notifier.
  // This MockBox is just a placeholder value.
}

// Mock StorageService
class MockStorageService extends Fake implements StorageService {
  final ValueNotifier<Box> _starredNotifier = ValueNotifier(MockBox());
  final Set<ChatMessage> _starredMessages = {};

  @override
  dynamic getSetting(String key, {dynamic defaultValue}) {
    // Return default values for appearance settings
    if (key == AppConstants.userMsgColorKey) return Colors.blue.toARGB32();
    if (key == AppConstants.aiMsgColorKey) return Colors.grey.toARGB32();
    if (key == AppConstants.bubbleRadiusKey) return 12.0;
    if (key == AppConstants.fontSizeKey) return 14.0;
    if (key == AppConstants.chatPaddingKey) return 8.0;
    if (key == AppConstants.showAvatarsKey) return true;
    if (key == AppConstants.bubbleElevationKey) return false;
    if (key == AppConstants.msgOpacityKey) return 1.0;
    return defaultValue;
  }

  @override
  ValueListenable<Box> get starredMessagesListenable => _starredNotifier;

  @override
  bool isMessageStarred(ChatMessage message) {
    return _starredMessages.contains(message);
  }

  // Helper for test to toggle star
  void toggleStar(ChatMessage message) {
    if (_starredMessages.contains(message)) {
      _starredMessages.remove(message);
    } else {
      _starredMessages.add(message);
    }
    // Notify listeners
    _starredNotifier.notifyListeners();
  }
}

void main() {
  testWidgets('ChatBubble renders and updates star icon correctly', (WidgetTester tester) async {
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

    // Initial state: Not starred
    expect(find.text('Hello World'), findsOneWidget);
    expect(find.byIcon(Icons.star), findsNothing);

    // Toggle star
    mockStorage.toggleStar(message);
    await tester.pump(); // Rebuild

    // State: Starred
    expect(find.byIcon(Icons.star), findsOneWidget);

    // Toggle star again
    mockStorage.toggleStar(message);
    await tester.pump(); // Rebuild

    // State: Not starred
    expect(find.byIcon(Icons.star), findsNothing);
  });
}
