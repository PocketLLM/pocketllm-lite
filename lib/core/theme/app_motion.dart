import 'package:flutter/material.dart';

/// Material 3 Expressive Motion System for PocketLLM Lite.
///
/// Provides spring-based animation definitions and standard durations/curves
/// following the M3 Expressive motion-physics guidance.
class AppMotion {
  // ── Spring Definitions ──

  /// Standard spring — general-purpose transitions and UI responses.
  static const SpringDescription standardSpring = SpringDescription(
    mass: 1.0,
    stiffness: 500,
    damping: 25,
  );

  /// Expressive spring — emphasized interactions (FAB press, dialog enter).
  /// Slight overshoot for a lively feel.
  static const SpringDescription expressiveSpring = SpringDescription(
    mass: 1.0,
    stiffness: 300,
    damping: 20,
  );

  /// Gentle spring — subtle effects (chat bubble entrance, fade-ins).
  static const SpringDescription gentleSpring = SpringDescription(
    mass: 1.0,
    stiffness: 200,
    damping: 22,
  );

  // ── Standard Durations ──

  /// Quick micro-interactions (ripples, icon changes).
  static const Duration durationXS = Duration(milliseconds: 100);

  /// Button press, toggle feedback.
  static const Duration durationSM = Duration(milliseconds: 150);

  /// Standard transitions (dialog exit, tooltip).
  static const Duration durationMD = Duration(milliseconds: 250);

  /// Screen transitions, modal enters.
  static const Duration durationLG = Duration(milliseconds: 350);

  /// Emphasized transitions (onboarding, first-paint).
  static const Duration durationXL = Duration(milliseconds: 500);

  // ── Standard Curves ──

  /// For entering content (coming into view).
  static const Curve curveEnter = Curves.easeOutCubic;

  /// For exiting content (leaving view).
  static const Curve curveExit = Curves.easeInCubic;

  /// For transitions that enter and exit (expanding/collapsing).
  static const Curve curveStandard = Curves.easeInOutCubicEmphasized;

  /// For dialog/sheet entrance — slight overshoot.
  static const Curve curveOvershoot = Curves.easeOutBack;

  /// For staggered list item animations.
  static Interval staggerInterval(
    int index,
    int total, {
    double overlap = 0.3,
  }) {
    final double start = (index / total) * (1.0 - overlap);
    final double end = start + (1.0 / total) + overlap * (1.0 / total);
    return Interval(
      start.clamp(0.0, 1.0),
      end.clamp(0.0, 1.0),
      curve: curveEnter,
    );
  }

  // ── Page Transition Builders ──

  /// Fade + slide up transition for GoRouter pages.
  static Widget fadeSlideTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: curveEnter),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.05),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: curveEnter)),
        child: child,
      ),
    );
  }

  /// Scale + fade transition (for dialogs, overlays).
  static Widget scaleFadeTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: curveEnter),
      child: ScaleTransition(
        scale: Tween<double>(
          begin: 0.92,
          end: 1.0,
        ).animate(CurvedAnimation(parent: animation, curve: curveOvershoot)),
        child: child,
      ),
    );
  }
}
