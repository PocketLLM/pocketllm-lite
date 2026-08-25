import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/core/theme/app_theme.dart';
import 'package:pocketllm_lite/core/widgets/m3_empty_state.dart';

void main() {
  for (final theme in <ThemeData>[AppTheme.lightTheme, AppTheme.darkTheme]) {
    testWidgets(
      'M3 empty state remains usable at 360dp with large text',
      (tester) async {
        tester.view.physicalSize = const Size(720, 1280);
        tester.view.devicePixelRatio = 2;
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(
          tester.platformDispatcher.clearTextScaleFactorTestValue,
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: M3EmptyState(
                icon: Icons.chat_bubble_outline,
                title: 'Start a private conversation',
                description:
                    'Import a supported model or connect a compatible local endpoint.',
                action: FilledButton(
                  onPressed: () {},
                  child: const Text('Choose model'),
                ),
              ),
            ),
          ),
        );

        expect(find.text('Start a private conversation'), findsOneWidget);
        expect(find.text('Choose model'), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(
          tester.getRect(find.text('Choose model')).bottom,
          lessThanOrEqualTo(tester.view.physicalSize.height / 2),
        );
      },
    );
  }
}
