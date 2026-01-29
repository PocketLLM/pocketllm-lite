import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/features/settings/presentation/widgets/model_download_dialog.dart';
import 'package:pocketllm_lite/core/providers.dart';
import 'package:pocketllm_lite/services/ollama_service.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

@GenerateNiceMocks([MockSpec<OllamaService>()])
import 'model_download_dialog_test.mocks.dart';

void main() {
  testWidgets('ModelDownloadDialog shows popular model chips', (
    WidgetTester tester,
  ) async {
    final mockOllamaService = MockOllamaService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [ollamaServiceProvider.overrideWithValue(mockOllamaService)],
        child: const MaterialApp(home: Scaffold(body: ModelDownloadDialog())),
      ),
    );

    // Verify "Popular Models:" text exists
    expect(find.text('Popular Models:'), findsOneWidget);

    // Verify chips exist
    expect(find.text('llama3.2'), findsOneWidget);
    expect(find.text('mistral'), findsOneWidget);
    expect(find.text('phi3'), findsOneWidget);

    // Tap a chip
    await tester.tap(find.text('llama3.2'));
    await tester.pump();

    // Verify TextField is updated
    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.controller?.text, 'llama3.2');
  });
}
