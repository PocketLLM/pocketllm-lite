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
import 'package:mockito/annotations.dart';
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
    // Return a large list to simulate performance need
    return List.generate(100, (index) => ChatSession(
      id: 'id_$index',
      title: 'Chat $index',
      model: 'llama3',
      messages: [],
      createdAt: DateTime.now().subtract(Duration(days: index)),
    ));
  }

  @override
  bool isArchived(String id) => false;

  @override
  bool isPinned(String id) => id == 'id_0';

  @override
  List<String> getTagsForChat(String id) => [];
}

class MockBox extends Mock implements Box<ChatSession> {
  @override
  bool get isEmpty => false;

  @override
  bool get isNotEmpty => true;

  @override
  int get length => 100;

  @override
  Iterable<String> get keys => [];
}

class MockUsageLimitsNotifier extends UsageLimitsNotifier {
  MockUsageLimitsNotifier();

  @override
  bool canCreateChat() => true;
}

void main() {
  testWidgets('ChatHistoryScreen uses CustomScrollView for performance', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(MockStorageService()),
          usageLimitsProvider.overrideWith(() => MockUsageLimitsNotifier()),
        ],
        child: MaterialApp(
          home: ChatHistoryScreen(),
        ),
      ),
    );

    // Verify that we have a CustomScrollView (which means we are using Slivers)
    expect(find.byType(CustomScrollView), findsOneWidget);

    // We expect to find multiple ListTiles rendered
    expect(find.byType(ListTile), findsAtLeastNWidgets(1));

    // Allow time for the banner ad timer to complete (500ms delay in initState)
    await tester.pump(const Duration(seconds: 1));
  });
}
