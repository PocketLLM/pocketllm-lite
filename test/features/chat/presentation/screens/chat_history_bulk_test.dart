import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/core/providers.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_session.dart';
import 'package:pocketllm_lite/features/chat/presentation/screens/chat_history_screen.dart';
import 'package:pocketllm_lite/services/storage_service.dart';
import 'package:hive_flutter/hive_flutter.dart';

// Manual Mock StorageService
class MockStorageService extends Fake implements StorageService {
  @override
  ValueListenable<Box<ChatSession>> get chatBoxListenable =>
      ValueNotifier<Box<ChatSession>>(MockBox());

  @override
  List<ChatSession> getChatSessions() => [];

  @override
  List<ChatSession> searchSessions({
    String query = '',
    String? model,
    DateTime? fromDate,
    String? tag,
  }) => [];

  @override
  List<String> getPinnedChatIds() => [];

  @override
  List<String> getArchivedChatIds() => [];

  @override
  List<String> getTagsForChat(String chatId) => [];

  @override
  Future<void> bulkArchiveChats(List<String> chatIds) async {}

  @override
  Future<void> bulkAddTag(List<String> chatIds, String tag) async {}

  @override
  bool isArchived(String chatId) => false;

  @override
  bool isPinned(String chatId) => false;

  @override
  Set<String> getAvailableModels() => {};

  @override
  Set<String> getAllTags() => {};
}

// Manual Mock Box
class MockBox extends Fake implements Box<ChatSession> {
  @override
  int get length => 0;

  @override
  Iterable<String> get keys => [];

  @override
  bool get isEmpty => true;

  @override
  bool get isNotEmpty => false;

  @override
  Iterable<ChatSession> get values => [];
}

void main() {
  testWidgets('ChatHistoryScreen shows bulk action buttons in selection mode', (WidgetTester tester) async {
    final mockStorage = MockStorageService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(mockStorage),
        ],
        child: MaterialApp(
          home: ChatHistoryScreen(),
        ),
      ),
    );

    // Initial state: No selection mode
    expect(find.byIcon(Icons.checklist), findsOneWidget); // Manage Chats button
    // Archive icon exists in App Bar actions normally (View Archived), so searching by icon might be ambiguous.
    // In normal mode: Archived Chats button (archive_outlined)
    // In selection mode: Archive selected chats (archive_outlined)
    // The difference is the tooltip or position.

    // Manage Chats button (checklist) puts us in selection mode.
    await tester.tap(find.byIcon(Icons.checklist));
    await tester.pumpAndSettle();

    // Verify bulk action buttons appear
    // We can verify by Tooltip to be sure
    expect(find.byTooltip('Archive selected chats'), findsOneWidget);
    expect(find.byTooltip('Tag selected chats'), findsOneWidget);
    expect(find.byTooltip('Export selected chats'), findsOneWidget);
    expect(find.byTooltip('Delete selected chats'), findsOneWidget);

    // Verify "Manage Chats" button is gone (replaced by Close)
    expect(find.byIcon(Icons.checklist), findsNothing);
    expect(find.byIcon(Icons.close), findsOneWidget);
  });
}
