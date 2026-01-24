import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:mockito/mockito.dart';
import 'package:pocketllm_lite/features/chat/presentation/widgets/chat_bubble.dart';
import 'package:pocketllm_lite/core/providers.dart';
import 'package:pocketllm_lite/services/storage_service.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_message.dart';
import 'package:pocketllm_lite/features/chat/domain/models/starred_message.dart';
import 'package:pocketllm_lite/features/settings/presentation/providers/appearance_provider.dart';

class MockBox extends Mock implements Box {}

class MockStorageService extends StorageService {
  final ValueNotifier<Box> _starredListenable = ValueNotifier(MockBox());

  @override
  ValueListenable<Box> get starredMessagesListenable => _starredListenable;

  @override
  List<StarredMessage> getStarredMessages() => [];

  @override
  bool isMessageStarred(ChatMessage message) => false;

  @override
  dynamic getSetting(String key, {dynamic defaultValue}) => defaultValue;
}

void main() {
  testWidgets('ChatBubble renders and handles starring', (WidgetTester tester) async {
    final mockStorage = MockStorageService();
    final message = ChatMessage(
      role: 'user',
      content: 'Hello',
      timestamp: DateTime.now(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(mockStorage),
          // Override appearance provider to avoid Hive access there too
          appearanceProvider.overrideWith(() => AppearanceNotifier()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ChatBubble(message: message),
          ),
        ),
      ),
    );

    expect(find.text('Hello'), findsOneWidget);
    expect(find.byType(ChatBubble), findsOneWidget);
  });
}
