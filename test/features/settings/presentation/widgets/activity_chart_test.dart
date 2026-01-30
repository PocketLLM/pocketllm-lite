import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:pocketllm_lite/features/settings/presentation/widgets/activity_chart.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

void main() {
  testWidgets('ActivityChart has correct accessibility label', (
    WidgetTester tester,
  ) async {
    final now = DateTime.now();
    final activity = [
      DailyActivity(now.subtract(const Duration(days: 6)), 5, 20),
      DailyActivity(now.subtract(const Duration(days: 5)), 0, 0),
      DailyActivity(now.subtract(const Duration(days: 4)), 10, 40),
      DailyActivity(now.subtract(const Duration(days: 3)), 2, 8),
      DailyActivity(now.subtract(const Duration(days: 2)), 0, 0),
      DailyActivity(now.subtract(const Duration(days: 1)), 8, 30),
      DailyActivity(now, 3, 10),
    ];
    // Total: 5 + 0 + 10 + 2 + 0 + 8 + 3 = 28
    // Peak: 10 (on now - 4 days)
    final peakDate = now.subtract(const Duration(days: 4));
    final peakDayName = DateFormat('EEEE').format(peakDate);

    final expectedLabelPart1 = 'Total 28 chats';
    final expectedLabelPart2 = 'Peak activity on $peakDayName with 10 chats';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ActivityChart(activity: activity)),
      ),
    );

    // Find semantics
    final semanticsFinder = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.label != null &&
          widget.properties.label!.contains(expectedLabelPart1) &&
          widget.properties.label!.contains(expectedLabelPart2),
    );

    expect(semanticsFinder, findsOneWidget);
  });

  testWidgets('ActivityChart handles empty activity', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ActivityChart(activity: [])),
      ),
    );

    final semanticsFinder = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.label == 'No activity data available.',
    );

    expect(semanticsFinder, findsOneWidget);
  });

  testWidgets('ActivityChart handles zero activity', (
    WidgetTester tester,
  ) async {
    final now = DateTime.now();
    final activity = [
      DailyActivity(now, 0, 0),
      DailyActivity(now.subtract(const Duration(days: 1)), 0, 0),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ActivityChart(activity: activity)),
      ),
    );

    final semanticsFinder = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.label == 'No activity in the last 7 days.',
    );

    expect(semanticsFinder, findsOneWidget);
  });
}
