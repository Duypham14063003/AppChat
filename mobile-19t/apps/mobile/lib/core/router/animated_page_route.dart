import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_motion.dart';

/// Types of page transitions available
enum TransitionType {
  /// Slide from right (iOS-style)
  slideFromRight,

  /// Slide from bottom (modal-style)
  slideFromBottom,

  /// Fade transition only
  fade,

  /// Fade + slide from right (Telegram-style)
  fadeSlide,

  /// Scale from center (dialog-style)
  scale,

  /// No animation
  none,
}

/// Extension on GoRouterState to easily create animated pages
extension AnimatedPageExtension on GoRouterState {
  /// Creates a CustomTransitionPage with the specified transition type
  CustomTransitionPage<T> animatedPage<T>({
    required Widget child,
    TransitionType type = TransitionType.fadeSlide,
    Duration duration = AppMotion.medium,
  }) {
    return CustomTransitionPage<T>(
      key: pageKey,
      child: child,
      transitionDuration: duration,
      reverseTransitionDuration: _reverseDuration(duration),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return _buildTransition(
          type: type,
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          child: child,
        );
      },
    );
  }
}

Duration _reverseDuration(Duration duration) {
  return Duration(milliseconds: (duration.inMilliseconds * 0.82).round());
}

/// Builds the appropriate transition based on type
Widget _buildTransition({
  required TransitionType type,
  required Animation<double> animation,
  required Animation<double> secondaryAnimation,
  required Widget child,
}) {
  switch (type) {
    case TransitionType.slideFromRight:
      return SlideTransition(
        position: Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero)
            .animate(
              CurvedAnimation(
                parent: animation,
                curve: AppMotion.enterCurve,
                reverseCurve: AppMotion.exitCurve,
              ),
            ),
        child: child,
      );

    case TransitionType.slideFromBottom:
      return SlideTransition(
        position: Tween<Offset>(begin: const Offset(0.0, 1.0), end: Offset.zero)
            .animate(
              CurvedAnimation(
                parent: animation,
                curve: AppMotion.enterCurve,
                reverseCurve: AppMotion.exitCurve,
              ),
            ),
        child: child,
      );

    case TransitionType.fade:
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: AppMotion.standardCurve,
          reverseCurve: AppMotion.exitCurve,
        ),
        child: child,
      );

    case TransitionType.fadeSlide:
      // Telegram-style: fade + slight slide
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: AppMotion.standardCurve,
          reverseCurve: AppMotion.exitCurve,
        ),
        child: SlideTransition(
          position:
              Tween<Offset>(
                begin: const Offset(0.02, 0.0),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: AppMotion.enterCurve,
                  reverseCurve: AppMotion.exitCurve,
                ),
              ),
          child: child,
        ),
      );

    case TransitionType.scale:
      return ScaleTransition(
        scale: Tween<double>(begin: 0.98, end: 1.0).animate(
          CurvedAnimation(
            parent: animation,
            curve: AppMotion.enterCurve,
            reverseCurve: AppMotion.exitCurve,
          ),
        ),
        child: FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: AppMotion.standardCurve,
            reverseCurve: AppMotion.exitCurve,
          ),
          child: child,
        ),
      );

    case TransitionType.none:
      return child;
  }
}

/// Helper to create an animated page for GoRouter
CustomTransitionPage<T> buildAnimatedPage<T>({
  required LocalKey key,
  required Widget child,
  TransitionType type = TransitionType.fadeSlide,
  Duration duration = AppMotion.medium,
}) {
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    transitionDuration: duration,
    reverseTransitionDuration: _reverseDuration(duration),
    transitionsBuilder: (context, animation, secondaryAnimation, childWidget) {
      return _buildTransition(
        type: type,
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        child: childWidget,
      );
    },
  );
}
