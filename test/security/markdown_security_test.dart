import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/core/utils/markdown_handlers.dart';

void main() {
  group('MarkdownHandlers Security Test', () {
    testWidgets('Blocks HTTP images', (WidgetTester tester) async {
      final uri = Uri.parse('http://example.com/image.png');
      final widget = MarkdownHandlers.imageBuilder(uri, 'Title', 'Alt Text');

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: widget,
        ),
      ));

      // Should show broken image icon
      expect(find.byIcon(Icons.broken_image), findsOneWidget);

      // Should show the alt text in the UI
      expect(find.text('Alt Text'), findsOneWidget);

      // Verify Tooltip exists with correct message
      final tooltipFinder = find.byType(Tooltip);
      expect(tooltipFinder, findsOneWidget);
      final tooltip = tester.widget<Tooltip>(tooltipFinder);
      expect(tooltip.message, 'Network image blocked for privacy');
    });

    testWidgets('Blocks HTTPS images', (WidgetTester tester) async {
      final uri = Uri.parse('https://example.com/image.png');
      final widget = MarkdownHandlers.imageBuilder(uri, 'Title', null);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: widget,
        ),
      ));

      expect(find.byIcon(Icons.broken_image), findsOneWidget);
      expect(find.text('Image blocked'), findsOneWidget);
    });

    testWidgets('Blocks other schemes (file, etc) by default as shrink', (WidgetTester tester) async {
       // The current implementation returns SizedBox.shrink() for non-http/https
      final uri = Uri.parse('file:///tmp/image.png');
      final widget = MarkdownHandlers.imageBuilder(uri, 'Title', 'Alt');

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: widget,
        ),
      ));

      expect(find.byIcon(Icons.broken_image), findsNothing);
      expect(find.text('Alt'), findsNothing);
      expect(find.byType(SizedBox), findsOneWidget);
    });
  });
}
