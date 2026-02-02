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

// Mock StorageService
class MockStorageService extends Fake implements StorageService {
  final ValueNotifier<Box> _boxNotifier = ValueNotifier(FakeBox());

  @override
  dynamic getSetting(String key, {dynamic defaultValue}) {
    if (key == AppConstants.userMsgColorKey) return 0xFF009688;
    if (key == AppConstants.aiMsgColorKey) return 0xFF424242;
    if (key == AppConstants.bubbleRadiusKey) return 12.0;
    if (key == AppConstants.fontSizeKey) return 14.0;
    if (key == AppConstants.chatPaddingKey) return 16.0;
    if (key == AppConstants.showAvatarsKey) return false;
    if (key == AppConstants.bubbleElevationKey) return false;
    if (key == AppConstants.msgOpacityKey) return 1.0;
    return defaultValue;
  }

  @override
  ValueListenable<Box> get starredMessagesListenable => _boxNotifier;

  @override
  bool isMessageStarred(ChatMessage message) => false;
}

class FakeBox extends Fake implements Box {}

void main() {
  testWidgets('ChatBubble renders user message correctly', (WidgetTester tester) async {
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

    expect(find.text('Hello World'), findsOneWidget);
  });

  testWidgets('ChatBubble renders AI message correctly', (WidgetTester tester) async {
    final mockStorage = MockStorageService();
    final message = ChatMessage(
      role: 'assistant',
      content: 'AI Response',
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

    expect(find.text('AI Response'), findsOneWidget);
  });
}
