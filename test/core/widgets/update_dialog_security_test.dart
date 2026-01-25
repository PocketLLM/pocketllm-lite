import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/core/widgets/update_dialog.dart';
import 'package:pocketllm_lite/services/update_service.dart';

void main() {
  testWidgets('UpdateDialog blocks network images in release notes',
      (WidgetTester tester) async {
    // Mock release with a network image in the body
    final release = AppRelease(
      tagName: 'v1.0.0',
      version: '1.0.0',
      name: 'Test Release',
      body: 'Here is an image: ![tracker](http://tracker.com/pixel.png)',
      publishedAt: DateTime.now(),
      apkDownloadUrl: 'http://example.com/app.apk',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UpdateDialog(release: release),
        ),
      ),
    );

    // Verify that the image is NOT rendered as a standard image
    // MarkdownHandlers.imageBuilder renders a Tooltip with a Container and broken image icon.
    // We look for the tooltip message or the specific structure.

    // Find Tooltip
    final tooltipFinder = find.byType(Tooltip);
    expect(tooltipFinder, findsOneWidget);

    final tooltip = tester.widget<Tooltip>(tooltipFinder);
    expect(tooltip.message, 'Network image blocked for privacy');

    // Find Broken Image Icon
    expect(find.byIcon(Icons.broken_image), findsOneWidget);

    // Find Alt Text (Optional, might be ellipsized or hidden)
    // expect(find.text('tracker'), findsOneWidget);
  });
}
