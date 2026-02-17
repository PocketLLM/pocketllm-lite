import 'package:flutter/material.dart';
import 'package:flutter_m3shapes/flutter_m3shapes.dart';

/// M3 Expressive empty state widget.
///
/// Displays a centered illustration (expressive shape with icon),
/// title, and description for screens with no content.
class M3EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Widget? action;
  final Shapes shape;
  final double iconSize;

  const M3EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.action,
    this.shape = Shapes.soft_burst,
    this.iconSize = 48,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            M3Container(
              shape,
              width: 100,
              height: 100,
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
              child: Center(
                child: Icon(
                  icon,
                  size: iconSize,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[const SizedBox(height: 24), action!],
          ],
        ),
      ),
    );
  }
}
