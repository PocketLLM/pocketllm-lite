import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketllm_lite/features/chat/presentation/widgets/templates_sheet.dart';
import 'package:pocketllm_lite/core/providers.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

class MockStorageService extends StorageService {
  @override
  List<Map<String, String>> getMessageTemplates() {
    return [];
  }
}

void main() {
  testWidgets('TemplatesSheet shows Create button in empty state when not full screen', (WidgetTester tester) async {
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

    // Initial pump
    await tester.pump();

    // The widget loads templates asynchronously (Future.delayed(Duration.zero) + setState)
    await tester.pumpAndSettle();

    // Verify empty state text is present
    expect(find.text('No templates yet'), findsOneWidget);

    // Verify Create New Template button is present (currently failing expectation)
    expect(find.text('Create New Template'), findsOneWidget);
  });
}
