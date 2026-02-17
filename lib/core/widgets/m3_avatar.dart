import 'package:flutter/material.dart';
import 'package:flutter_m3shapes/flutter_m3shapes.dart';

/// M3 Expressive Avatar widget using flutter_m3shapes.
///
/// Provides distinctive non-circular avatar shapes to differentiate
/// user vs AI messages, following M3 Expressive shape guidance.
class M3Avatar extends StatelessWidget {
  /// The child widget (typically an Icon, Text initial, or Image).
  final Widget child;

  /// Size of the avatar.
  final double size;

  /// Background color. Falls back to colorScheme.primaryContainer.
  final Color? backgroundColor;

  /// The M3 shape to use. Defaults to gem.
  final Shapes shape;

  const M3Avatar({
    super.key,
    required this.child,
    this.size = 40,
    this.backgroundColor,
    this.shape = Shapes.gem,
  });

  /// User avatar preset — gem shape with primary container color.
  factory M3Avatar.user({
    Key? key,
    required Widget child,
    double size = 40,
    Color? backgroundColor,
  }) {
    return M3Avatar(
      key: key,
      shape: Shapes.gem,
      size: size,
      backgroundColor: backgroundColor,
      child: child,
    );
  }

  /// AI/Model avatar preset — flower shape with secondary container color.
  factory M3Avatar.ai({
    Key? key,
    required Widget child,
    double size = 40,
    Color? backgroundColor,
  }) {
    return M3Avatar(
      key: key,
      shape: Shapes.flower,
      size: size,
      backgroundColor: backgroundColor,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = backgroundColor ?? theme.colorScheme.primaryContainer;

    return M3Container(
      shape,
      width: size,
      height: size,
      color: bg,
      child: Center(child: child),
    );
  }
}
