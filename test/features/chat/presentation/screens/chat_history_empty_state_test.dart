import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/features/chat/presentation/screens/chat_history_screen.dart';
import 'package:pocketllm_lite/services/storage_service.dart';
import 'package:pocketllm_lite/core/providers.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_session.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mockito/mockito.dart';
import 'package:pocketllm_lite/services/usage_limits_provider.dart';

// Create a mock StorageService
class MockStorageService extends Mock implements StorageService {
  @override
  ValueListenable<Box<ChatSession>> get chatBoxListenable =>
      ValueNotifier<Box<ChatSession>>(MockBox());

  @override
  List<ChatSession> searchSessions({
    String query = '',
    String? model,
    DateTime? fromDate,
    String? tag,
  }) {
    return []; // Return empty list to trigger empty state
  }

  @override
  bool isArchived(String id) => false;

  @override
  bool isPinned(String id) => false;

  @override
  List<String> getTagsForChat(String id) => [];

  @override
  Set<String> getAvailableModels() => {'llama3'};

  @override
  Set<String> getAllTags() => {};
}

class MockBox extends Mock implements Box<ChatSession> {
  @override
  bool get isEmpty => true;

  @override
  bool get isNotEmpty => false;

  @override
  int get length => 0;

  @override
  Iterable<String> get keys => [];
}

class MockUsageLimitsNotifier extends UsageLimitsNotifier {
  MockUsageLimitsNotifier();

  @override
  bool canCreateChat() => true;
}

void main() {
  testWidgets('ChatHistoryScreen empty state renders with animation', (
    WidgetTester tester,
  ) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(MockStorageService()),
          usageLimitsProvider.overrideWith(() => MockUsageLimitsNotifier()),
        ],
        child: MaterialApp(home: ChatHistoryScreen()),
      ),
    );

    // Initial pump
    await tester.pump();

    // Verify empty state content is present
    expect(find.text('No chat history'), findsOneWidget);
    expect(find.text('Start a new conversation to begin'), findsOneWidget);
    expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
    expect(find.text('Start New Chat'), findsOneWidget);

    // Verify TweenAnimationBuilder is present
    expect(find.byType(TweenAnimationBuilder<double>), findsOneWidget);

    // Pump frames to complete animation (300ms)
    await tester.pump(const Duration(milliseconds: 300));

    // Pump to handle the ad loading delay (500ms) to avoid pending timer exception
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // Verify content is still present after animation
    expect(find.text('No chat history'), findsOneWidget);
  });
}
