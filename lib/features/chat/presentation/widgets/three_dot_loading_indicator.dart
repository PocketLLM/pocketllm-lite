import 'package:flutter/material.dart';

class ThreeDotLoadingIndicator extends StatefulWidget {
  final Color color;
  final double size;
  final Duration animationDuration;

  const ThreeDotLoadingIndicator({
    super.key,
    this.color = Colors.grey,
    this.size = 8.0,
    this.animationDuration = const Duration(milliseconds: 500),
  });

  @override
  State<ThreeDotLoadingIndicator> createState() => _ThreeDotLoadingIndicatorState();
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

    // Initialize animations once to avoid per-frame allocation inside build/AnimatedBuilder
    _animations = List.generate(3, (index) {
      return Tween<double>(begin: 0.5, end: 1.0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(
            0.2 * index, // Stagger the animations
            0.2 * index + 0.6,
            curve: Curves.easeInOut,
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
    return Semantics(
      label: 'Loading...',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (index) {
          // Use nested transitions to avoid AnimatedBuilder's builder callback execution
          // and per-frame widget recreation.
          // The Container is built once (per ThreeDotLoadingIndicator build) and reused
          // by ScaleTransition/FadeTransition during animation ticks.
          return FadeTransition(
            opacity: _animations[index],
            child: ScaleTransition(
              scale: _animations[index],
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  color: widget.color,
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
