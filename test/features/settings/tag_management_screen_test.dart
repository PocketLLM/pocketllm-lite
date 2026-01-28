import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pocketllm_lite/core/providers.dart';
import 'package:pocketllm_lite/features/settings/presentation/screens/tag_management_screen.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

class MockBox extends Fake implements Box {}

class MockStorageService extends Fake implements StorageService {
  @override
  ValueListenable<Box> get settingsBoxListenable => ValueNotifier(MockBox());

  @override
  Map<String, int> getTagUsageCounts() {
    return {'Work': 5, 'Personal': 2};
  }

  @override
  Future<void> renameTag(String oldTag, String newTag) async {}

  @override
  Future<void> deleteTagGlobal(String tag) async {}
}

void main() {
  testWidgets('TagManagementScreen displays tags', (WidgetTester tester) async {
    final mockStorage = MockStorageService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(mockStorage),
        ],
        child: const MaterialApp(
          home: TagManagementScreen(),
        ),
      ),
    );

    // Initial build
    await tester.pump();

    // Verify app bar
    expect(find.text('Manage Tags'), findsOneWidget);

    // Verify tags are displayed
    expect(find.text('Work'), findsOneWidget);
    expect(find.text('5 chats'), findsOneWidget);
    expect(find.text('Personal'), findsOneWidget);
    expect(find.text('2 chats'), findsOneWidget);

    // Verify search field
    expect(find.byType(TextField), findsOneWidget);
  });
}
