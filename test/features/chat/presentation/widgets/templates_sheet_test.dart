import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketllm_lite/features/chat/presentation/widgets/templates_sheet.dart';
import 'package:pocketllm_lite/core/providers.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

// Mock StorageService
class MockStorageService extends StorageService {
  @override
  List<Map<String, String>> getMessageTemplates() {
    return []; // Return empty templates to trigger empty state
  }

  @override
  dynamic getSetting(String key, {dynamic defaultValue}) {
    return defaultValue;
  }
}

void main() {
  testWidgets('TemplatesSheet accessibility and empty state', (
    WidgetTester tester,
  ) async {
    final mockStorage = MockStorageService();

    // Pump the widget in non-fullscreen mode
    await tester.pumpWidget(
      ProviderScope(
        overrides: [storageServiceProvider.overrideWithValue(mockStorage)],
        child: MaterialApp(
          home: Scaffold(
            body: TemplatesSheet(onSelect: (_) {}, isFullScreen: false),
          ),
        ),
      ),
    );

    // Wait for async load
    await tester.pumpAndSettle();

    // 1. Verify "Quick Templates" header
    final headerFinder = find.text('Quick Templates');
    expect(headerFinder, findsOneWidget);
    // Check Semantics - expecting failure initially
    // The test will fail here if I don't implement the change.
    // However, I want to write the test to PASS with my intended changes.
    // So I will assert what SHOULD be there.

    final headerSemantics = tester.getSemantics(headerFinder);
    expect(
      headerSemantics.hasFlag(SemanticsFlag.isHeader),
      isTrue,
      reason: 'Quick Templates should be a header',
    );

    // 2. Verify Empty State Icon is excluded
    final iconFinder = find.byIcon(Icons.bolt);
    // There might be multiple bolt icons (header button has one? no, header has add button).
    // The list tile has bolt icon, but list is empty.
    // The empty state has a bolt icon.
    expect(iconFinder, findsOneWidget);

    // We can't easily check 'excludeSemantics' directly via `getSemantics` because the node might not exist or be merged.
    // But we can check if the parent Semantics node with 'excludeSemantics: true' exists.
    // Or check that the icon does NOT have a semantic node.

    // Easier way: Find the icon widget and check its parent is Semantics with excludeSemantics: true
    final semanticsFinder = find.ancestor(
      of: iconFinder,
      matching: find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.excludeSemantics == true,
      ),
    );
    expect(
      semanticsFinder,
      findsOneWidget,
      reason: 'Empty state icon should be excluded from semantics',
    );

    // 3. Verify "No templates yet" header
    final emptyTextFinder = find.text('No templates yet');
    expect(emptyTextFinder, findsOneWidget);
    final emptyTextSemantics = tester.getSemantics(emptyTextFinder);
    expect(
      emptyTextSemantics.hasFlag(SemanticsFlag.isHeader),
      isTrue,
      reason: 'No templates yet should be a header',
    );

    // 4. Verify CTA Button "Create New Template" exists
    final ctaTextFinder = find.text('Create New Template');
    expect(
      ctaTextFinder,
      findsOneWidget,
      reason: 'CTA button text should be visible',
    );
  });
}
