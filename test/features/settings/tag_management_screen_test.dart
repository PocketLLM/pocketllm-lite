import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pocketllm_lite/core/providers.dart';
import 'package:pocketllm_lite/features/settings/presentation/screens/tag_management_screen.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

class FakeBox extends Fake implements Box {}

class MockStorageService extends StorageService {
  final ValueNotifier<Box> _boxNotifier = ValueNotifier<Box>(FakeBox());
  final Set<String> _tags = {'work', 'personal'};

  @override
  ValueListenable<Box> get settingsBoxListenable => _boxNotifier;

  @override
  Set<String> getAllTags() => _tags;

  // Override to prevent Hive.initFlutter() call in base class or other calls
  // Actually StorageService is not abstract, so we just override what's used.
}

void main() {
  testWidgets('TagManagementScreen renders tags', (tester) async {
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

    // Verify AppBar
    expect(find.text('Manage Tags'), findsOneWidget);

    // Verify Tags
    expect(find.text('work'), findsOneWidget);
    expect(find.text('personal'), findsOneWidget);
  });
}
