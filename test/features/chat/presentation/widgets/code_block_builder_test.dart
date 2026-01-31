import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/features/chat/presentation/widgets/code_block_builder.dart';

void main() {
  testWidgets('CodeBlockBuilder renders copy button and handles tap', (
    WidgetTester tester,
  ) async {
    // Setup Clipboard mock
    final log = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (
          MethodCall methodCall,
        ) async {
          log.add(methodCall);
          return null;
        });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return MarkdownBody(
                data: '```dart\nprint("Hello");\n```',
                builders: {
                  'pre': CodeBlockBuilder(context),
                  'code': CodeBlockBuilder(context),
                },
              );
            },
          ),
        ),
      ),
    );

    // Verify code text is rendered
    final selectableText = find.byType(SelectableText);
    expect(selectableText, findsOneWidget);
    final widget = tester.widget<SelectableText>(selectableText);
    expect(widget.data, contains('print("Hello");'));

    // Verify language label (CodeBlockBuilder uppercases it)
    expect(find.text('DART'), findsOneWidget);

    // Verify Copy Button exists
    final copyButton = find.byIcon(Icons.copy);
    expect(copyButton, findsOneWidget);

    // Tap copy button
    await tester.tap(copyButton);
    await tester.pump(); // Start animation
    await tester.pump(const Duration(seconds: 1)); // Finish animation (SnackBar)

    // Verify Clipboard.setData was called
    // We check if any call to Clipboard.setData with correct text exists
    final clipboardCalls = log.where((call) => call.method == 'Clipboard.setData');
    expect(clipboardCalls, isNotEmpty);
    expect(clipboardCalls.last.arguments['text'], 'print("Hello");');

    // Verify SnackBar
    expect(find.text('Code copied to clipboard'), findsOneWidget);
  });
}
