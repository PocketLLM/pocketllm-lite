import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketllm_lite/features/chat/presentation/widgets/templates_sheet.dart';
import 'package:pocketllm_lite/core/providers.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

// Mock StorageService
class MockStorageService extends StorageService {
  @override
  List<Map<String, String>> getMessageTemplates() {
    return []; // Return empty list to trigger empty state
  }

  @override
  dynamic getSetting(String key, {dynamic defaultValue}) {
    return defaultValue;
  }
}

void main() {
  testWidgets('TemplatesSheet shows Create button in empty state (non-fullscreen)', (WidgetTester tester) async {
    final mockStorage = MockStorageService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(mockStorage),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: TemplatesSheet(
              onSelect: (_) {},
              isFullScreen: false, // Explicitly non-fullscreen
            ),
          ),
        ),
      ),
    );

    // Pump to allow async loading to complete (if any)
    await tester.pumpAndSettle();

    // Verify "No templates yet" text is present
    expect(find.text('No templates yet'), findsOneWidget);

    // Verify "Create New Template" button is present in the empty state
    // We look for the text "Create New Template" which is in the button.
    expect(find.text('Create New Template'), findsOneWidget);

    // We can also verify the icon is near it if we want, or just finding the text is enough proof
    // that the button content is rendered.
    expect(find.byIcon(Icons.add), findsWidgets); // One in header, one in empty state
  });

  testWidgets('TemplatesSheet has correct semantics for headers', (WidgetTester tester) async {
    final mockStorage = MockStorageService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(mockStorage),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: TemplatesSheet(
              onSelect: (_) {},
              isFullScreen: false,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify "Quick Templates" header semantics
    final quickTemplatesHandle = tester.widget<Semantics>(
      find.ancestor(
        of: find.text('Quick Templates'),
        matching: find.byType(Semantics),
      ).first
    );
    expect(quickTemplatesHandle.properties.header, isTrue);

     final noTemplatesHandle = tester.widget<Semantics>(
      find.ancestor(
        of: find.text('No templates yet'),
        matching: find.byType(Semantics),
      ).first
    );
    expect(noTemplatesHandle.properties.header, isTrue);
  });
}
