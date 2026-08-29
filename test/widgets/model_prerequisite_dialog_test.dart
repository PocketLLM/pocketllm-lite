import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/core/widgets/model_prerequisite_dialog.dart';
import 'package:pocketllm_lite/features/model_browser/domain/model_store_model.dart';
import 'package:pocketllm_lite/features/model_browser/providers/model_store_provider.dart';

void main() {
  testWidgets('fits guided model setup on a compact large-text screen',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    ModelPrerequisiteResult? result;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          modelStoreCatalogProvider.overrideWith(
            (_) async => const [
              ModelStoreModel(
                id: 'qwen3-0.6-embed',
                name: 'Qwen 3 0.6B Embed',
                runtime: ModelStoreRuntime.onDevice,
                sizeMb: 394,
                downloadUrl: 'https://example.test/model.zip',
                archiveFilename: 'model.zip',
                quantizationBits: 8,
                capabilities: {'Embeddings'},
                source: 'Cactus Flutter 1.3 catalog',
                license: 'Apache-2.0 (upstream weights)',
              ),
            ],
          ),
        ],
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 640),
              textScaler: TextScaler.linear(1.3),
            ),
            child: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () async {
                      result = await showModelPrerequisiteDialog(
                        context: context,
                        modelId: 'qwen3-0.6-embed',
                        title: 'Set up document search',
                        explanation:
                            'This model is required to search documents.',
                      );
                    },
                    child: const Text('Open setup'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open setup'));
    await tester.pumpAndSettle();

    expect(find.text('Set up document search'), findsOneWidget);
    expect(find.text('Qwen 3 0.6B Embed'), findsOneWidget);
    expect(find.text('Download now'), findsOneWidget);
    expect(find.text('Choose another'), findsOneWidget);
    expect(find.text('Not now'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(result, ModelPrerequisiteResult.skipped);
  });
}
