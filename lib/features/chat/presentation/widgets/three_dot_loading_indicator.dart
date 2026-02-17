import 'package:flutter/material.dart';

class ThreeDotLoadingIndicator extends StatefulWidget {
  final Color? color;
  final double size;
  final Duration animationDuration;

  const ThreeDotLoadingIndicator({
    super.key,
    this.color,
    this.size = 8.0,
    this.animationDuration = const Duration(milliseconds: 600),
  });

  @override
  State<ThreeDotLoadingIndicator> createState() =>
      _ThreeDotLoadingIndicatorState();
}

class _ThreeDotLoadingIndicatorState extends State<ThreeDotLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    )..repeat(reverse: true);

    _animations = List.generate(3, (index) {
      return Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(
            0.2 * index,
            0.2 * index + 0.6,
            curve: Curves.easeInOutCubicEmphasized,
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dotColor =
        widget.color ?? Theme.of(context).colorScheme.onSurfaceVariant;

    return Semantics(
      label: 'Loading...',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (index) {
          return FadeTransition(
            opacity: _animations[index],
            child: ScaleTransition(
              scale: _animations[index],
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
