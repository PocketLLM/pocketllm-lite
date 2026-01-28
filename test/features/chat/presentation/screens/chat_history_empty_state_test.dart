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

// Create a mock StorageService for empty state
class MockStorageServiceEmpty extends Mock implements StorageService {
  @override
  ValueListenable<Box<ChatSession>> get chatBoxListenable =>
      ValueNotifier<Box<ChatSession>>(MockBoxEmpty());

  @override
  List<ChatSession> searchSessions({
    String query = '',
    String? model,
    DateTime? fromDate,
    String? tag,
  }) {
    return [];
  }

  @override
  bool isArchived(String id) => false;
}

class MockBoxEmpty extends Mock implements Box<ChatSession> {
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
  testWidgets('ChatHistoryScreen displays animated empty state when no chats', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(MockStorageServiceEmpty()),
          usageLimitsProvider.overrideWith(() => MockUsageLimitsNotifier()),
        ],
        child: MaterialApp(
          home: ChatHistoryScreen(),
        ),
      ),
    );

    // Initial pump
    await tester.pump();

    // Verify empty state texts are present
    expect(find.text('No chat history'), findsOneWidget);
    expect(find.text('Start a new conversation to begin'), findsOneWidget);

    // Check header semantics widget with specific text
    final headerSemanticsFinder = find.byWidgetPredicate((widget) {
      if (widget is Semantics && widget.properties.header == true) {
         final child = widget.child;
         if (child is Text && child.data == 'No chat history') {
           return true;
         }
      }
      return false;
    });
    expect(headerSemanticsFinder, findsOneWidget);

    // Check excluded semantics for icon
    final excludedSemanticsFinder = find.byWidgetPredicate((widget) {
      if (widget is Semantics && widget.excludeSemantics == true) {
        return true;
      }
      return false;
    });
    expect(excludedSemanticsFinder, findsOneWidget);

    // Verify TweenAnimationBuilder is present
    expect(find.byType(TweenAnimationBuilder<double>), findsOneWidget);

    // Advance animation
    await tester.pump(const Duration(milliseconds: 600));
  });
}
