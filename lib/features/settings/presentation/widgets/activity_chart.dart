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
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 220,
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(24),
          ),
          child: CustomPaint(
            size: const Size(double.infinity, 150),
            painter: BarChartPainter(
              activity: activity,
              primaryColor: theme.colorScheme.primary,
              surfaceVariantColor: theme.colorScheme.surfaceContainerHighest,
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
  final Color surfaceVariantColor;
  final Color onSurfaceColor;

  BarChartPainter({
    required this.activity,
    required this.primaryColor,
    required this.surfaceVariantColor,
    required this.onSurfaceColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (activity.isEmpty) return;

    final paint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.fill;

    final bgPaint = Paint()
      ..color = surfaceVariantColor
      ..style = PaintingStyle.fill;

    final textStyle = TextStyle(
      color: onSurfaceColor.withValues(alpha: 0.7),
      fontSize: 11,
      fontWeight: FontWeight.w600,
    );

    final double barWidth = size.width / (activity.length * 1.8);
    final double maxVal = activity
        .map((e) => e.chatCount)
        .reduce((a, b) => a > b ? a : b)
        .toDouble();
    final double effectiveMax = maxVal > 0 ? maxVal : 5;

    // Leave space for text at bottom
    final double chartHeight = size.height - 24;

    for (int i = 0; i < activity.length; i++) {
      final item = activity[i];
      final double barHeight = (item.chatCount / effectiveMax) * chartHeight;
      final double x =
          (i * size.width / activity.length) +
          (size.width / activity.length - barWidth) / 2;

      // Draw background pill (full height)
      final bgRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, 0, barWidth, chartHeight),
        Radius.circular(barWidth / 2),
      );
      canvas.drawRRect(bgRect, bgPaint);

      // Draw active pill (value height)
      if (item.chatCount > 0) {
        // Minimum height to be visible as a pill
        final double effectiveBarHeight = barHeight < barWidth
            ? barWidth
            : barHeight;

        final y = chartHeight - effectiveBarHeight;

        final r = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, effectiveBarHeight),
          Radius.circular(barWidth / 2),
        );
        canvas.drawRRect(r, paint);
      }

      // Draw Label (Day)
      final textSpan = TextSpan(
        text: DateFormat.E().format(item.date)[0],
        style: textStyle,
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: ui.TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x + (barWidth - textPainter.width) / 2, size.height - 14),
      );

      // Draw Value tooltip above
      if (item.chatCount > 0) {
        final countSpan = TextSpan(
          text: item.chatCount.toString(),
          style: textStyle.copyWith(
            fontWeight: FontWeight.bold,
            color: onSurfaceColor,
            fontSize: 10,
          ),
        );
        final countPainter = TextPainter(
          text: countSpan,
          textDirection: ui.TextDirection.ltr,
        );
        countPainter.layout();

        // Only draw if it fits above, otherwise skip to keep clean
        if (chartHeight - barHeight > 15) {
          countPainter.paint(
            canvas,
            Offset(
              x + (barWidth - countPainter.width) / 2,
              chartHeight - barHeight - 16,
            ),
          );
        }
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
