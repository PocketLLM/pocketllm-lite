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

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            // Create a staggered animation effect
            final animation = Tween<double>(begin: 0.5, end: 1.0).animate(
              CurvedAnimation(
                parent: _controller,
                curve: Interval(
                  0.2 * index, // Stagger the animations
                  0.2 * index + 0.6,
                  curve: Curves.easeInOut,
                ),
              ),
            );
            
            return FadeTransition(
              opacity: animation,
              child: Transform.scale(
                scale: animation.value,
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
          },
        );
      }),
    );
  }
}