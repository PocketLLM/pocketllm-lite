import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Reusable M3 Expressive AppBar for consistent navigation styling across
/// all screens in the application.
///
/// Supports optional [subtitle], custom [leading], [actions], and
/// flexible title widgets via [titleWidget].
class M3AppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final Widget? titleWidget;
  final Widget? leading;
  final List<Widget>? actions;
  final bool centerTitle;
  final double elevation;
  final VoidCallback? onBack;
  final bool automaticallyImplyLeading;
  final PreferredSizeWidget? bottom;
  final Color? backgroundColor;

  const M3AppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.titleWidget,
    this.leading,
    this.actions,
    this.centerTitle = false,
    this.elevation = 0,
    this.onBack,
    this.automaticallyImplyLeading = true,
    this.bottom,
    this.backgroundColor,
  });

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Widget titleContent;
    if (titleWidget != null) {
      titleContent = titleWidget!;
    } else if (subtitle != null) {
      titleContent = Column(
        crossAxisAlignment: centerTitle
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            subtitle!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    } else {
      titleContent = Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      );
    }

    return AppBar(
      title: titleContent,
      centerTitle: centerTitle,
      elevation: elevation,
      scrolledUnderElevation: 1,
      backgroundColor: backgroundColor ?? colorScheme.surface,
      surfaceTintColor: colorScheme.surfaceTint,
      leading:
          leading ??
          (automaticallyImplyLeading
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    if (onBack != null) {
                      onBack!();
                    } else {
                      Navigator.maybePop(context);
                    }
                  },
                )
              : null),
      automaticallyImplyLeading: automaticallyImplyLeading,
      actions: actions,
      bottom: bottom,
    );
  }
}
