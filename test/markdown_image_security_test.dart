import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/core/widgets/update_dialog.dart';
import 'package:pocketllm_lite/services/update_service.dart';

void main() {
  testWidgets('UpdateDialog blocks network images in release notes',
      (WidgetTester tester) async {
    // 1. Create a release with a malicious image in the body
    final maliciousRelease = AppRelease(
      tagName: 'v2.0.0',
      version: '2.0.0',
      name: 'Major Update',
      body: 'Here is a cool feature: ![Tracker](http://malicious.com/pixel.png)',
      publishedAt: DateTime.now(),
      apkDownloadUrl: 'https://github.com/example/app.apk',
    );

    // 2. Pump the widget
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UpdateDialog(release: maliciousRelease),
        ),
      ),
    );

    // 3. Verify that the image is NOT loaded and the security placeholder is shown
    // The placeholder uses Icons.broken_image
    final brokenIconFinder = find.byIcon(Icons.broken_image);

    // This should FAIL before the fix, and PASS after the fix
    // Because without the handler, flutter_markdown will try to render an Image widget.
    // However, since we are in a test environment, network images might just fail silently or throw.
    // But importantly, the 'broken_image' icon from our Handler won't be there.
    expect(brokenIconFinder, findsOneWidget);

    // Verify the tooltip text is present
    expect(find.byTooltip('Network image blocked for privacy'), findsOneWidget);
  });
}
