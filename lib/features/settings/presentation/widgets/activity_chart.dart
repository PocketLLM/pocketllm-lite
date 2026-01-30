import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../services/storage_service.dart';

class ActivityChart extends StatelessWidget {
  final List<DailyActivity> activity;

  const ActivityChart({super.key, required this.activity});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Weekly Activity',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Container(
          height: 180,
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: CustomPaint(
            size: const Size(double.infinity, 150),
            painter: BarChartPainter(
              activity: activity,
              primaryColor: theme.colorScheme.primary,
              onSurfaceColor: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

class BarChartPainter extends CustomPainter {
  final List<DailyActivity> activity;
  final Color primaryColor;
  final Color onSurfaceColor;

  BarChartPainter({
    required this.activity,
    required this.primaryColor,
    required this.onSurfaceColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (activity.isEmpty) return;

    final paint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.fill;

    final textStyle = TextStyle(
      color: onSurfaceColor.withValues(alpha: 0.7),
      fontSize: 10,
    );

    final double barWidth = size.width / (activity.length * 1.5); // Adjust gap
    final double maxVal = activity.map((e) => e.chatCount).reduce((a, b) => a > b ? a : b).toDouble();
    // Ensure we have some height even if max is 0. If max is 0, effectiveMax is 5 (to show empty grid-like scale)
    final double effectiveMax = maxVal > 0 ? maxVal : 5;

    // Leave space for text at bottom
    final double chartHeight = size.height - 20;

    for (int i = 0; i < activity.length; i++) {
      final item = activity[i];
      final double barHeight = (item.chatCount / effectiveMax) * chartHeight;
      final double x = (i * size.width / activity.length) + (size.width / activity.length - barWidth) / 2;
      final double y = chartHeight - barHeight;

      // Draw Bar
      // If barHeight is 0, draw a tiny line or nothing?
      // Let's draw a 2px high bar with low opacity for 0 values to show the slot?
      // Or just nothing.
      if (item.chatCount > 0) {
        final r = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, barHeight),
          const Radius.circular(4),
        );
        canvas.drawRRect(r, paint);
      } else {
        // Draw placeholder for 0
        final placeholderPaint = Paint()
          ..color = onSurfaceColor.withValues(alpha: 0.1)
          ..style = PaintingStyle.fill;
        final r = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, chartHeight - 2, barWidth, 2),
          const Radius.circular(1),
        );
        canvas.drawRRect(r, placeholderPaint);
      }

      // Draw Label (Day)
      final textSpan = TextSpan(
        text: DateFormat.E().format(item.date)[0], // First letter of day (M, T, W...)
        style: textStyle.copyWith(fontWeight: FontWeight.w600),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: ui.TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x + (barWidth - textPainter.width) / 2, size.height - 15),
      );

      // Draw Value (Count) if bar is tall enough, otherwise above
      if (item.chatCount > 0) {
         final countSpan = TextSpan(
          text: item.chatCount.toString(),
          style: textStyle.copyWith(
            fontWeight: FontWeight.bold,
            color: onSurfaceColor, // Use main color for visibility
            fontSize: 11,
          ),
        );
        final countPainter = TextPainter(
          text: countSpan,
          textDirection: ui.TextDirection.ltr,
        );
        countPainter.layout();
        countPainter.paint(
          canvas,
          Offset(x + (barWidth - countPainter.width) / 2, y - 16),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant BarChartPainter oldDelegate) {
    return oldDelegate.activity != activity ||
           oldDelegate.primaryColor != primaryColor ||
           oldDelegate.onSurfaceColor != onSurfaceColor;
  }
}
