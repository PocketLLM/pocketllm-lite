import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pocketllm_lite/core/providers.dart';
import 'package:pocketllm_lite/features/settings/presentation/screens/tag_management_screen.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

// Mock Box
class MockBox extends Fake implements Box {}

// Mock Storage Service
class MockStorageService extends StorageService {
  final Map<String, List<String>> _tagsMap;
  final ValueNotifier<Box> _listenable = ValueNotifier(MockBox());

  MockStorageService(this._tagsMap);

  @override
  Set<String> getAllTags() {
    final all = <String>{};
    for (final list in _tagsMap.values) {
      all.addAll(list);
    }
    return all;
  }

  @override
  ValueListenable<Box> get settingsBoxListenable => _listenable;

  @override
  Future<void> renameTag(String oldTag, String newTag) async {
    // No-op
  }

  @override
  Future<void> deleteTag(String tag) async {
    // No-op
  }
}

void main() {
  testWidgets('TagManagementScreen shows tags', (tester) async {
    final mockStorage = MockStorageService({
      'chat1': ['flutter', 'dart'],
      'chat2': ['ai'],
    });

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

    await tester.pumpAndSettle();

    expect(find.text('flutter'), findsOneWidget);
    expect(find.text('dart'), findsOneWidget);
    expect(find.text('ai'), findsOneWidget);
    expect(find.text('Manage Tags'), findsOneWidget);
  });
}
