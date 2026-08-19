import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_interaction.dart';
import '../../core/theme/app_motion.dart';

/// A FloatingActionButton with enhanced animations.
///
/// Features:
/// - Scale bounce animation on tap
/// - Optional rotation animation
/// - Smooth transitions
///
/// Example:
/// ```dart
/// AnimatedFAB(
///   icon: Icons.add,
///   onPressed: () => _createNew(),
///   rotateOnTap: true,
/// )
/// ```
class AnimatedFAB extends StatefulWidget {
  const AnimatedFAB({
    super.key,
    required this.icon,
    required this.onPressed,
    this.backgroundColor,
    this.foregroundColor,
    this.tooltip,
    this.rotateOnTap = false,
    this.enableHaptic = true,
    this.heroTag,
  });

  /// The icon to display
  final IconData icon;

  /// Called when the FAB is pressed
  final VoidCallback? onPressed;

  /// Background color
  final Color? backgroundColor;

  /// Foreground color (icon color)
  final Color? foregroundColor;

  /// Tooltip text
  final String? tooltip;

  /// Whether to rotate 180° on tap
  final bool rotateOnTap;

  /// Whether to trigger haptic feedback
  final bool enableHaptic;

  /// Hero tag for hero animations
  final Object? heroTag;

  @override
  State<AnimatedFAB> createState() => _AnimatedFABState();
}

class _AnimatedFABState extends State<AnimatedFAB>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _rotationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();

    _scaleController = AnimationController(
      vsync: this,
      duration: AppMotion.fast,
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 0.94,
        ).chain(CurveTween(curve: AppMotion.standardCurve)),
        weight: 55,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.94,
          end: 1.03,
        ).chain(CurveTween(curve: AppMotion.enterCurve)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.03,
          end: 1.0,
        ).chain(CurveTween(curve: AppMotion.standardCurve)),
        weight: 20,
      ),
    ]).animate(_scaleController);

    _rotationController = AnimationController(
      vsync: this,
      duration: AppMotion.medium,
    );

    _rotationAnimation = Tween<double>(begin: 0.0, end: 0.5).animate(
      CurvedAnimation(
        parent: _rotationController,
        curve: AppMotion.standardCurve,
      ),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.onPressed == null) return;

    if (widget.enableHaptic) {
      HapticFeedback.mediumImpact();
    }

    // Trigger scale bounce
    _scaleController.forward().then((_) => _scaleController.reverse());

    // Trigger rotation if enabled
    if (widget.rotateOnTap) {
      if (_rotationController.isCompleted) {
        _rotationController.reverse();
      } else {
        _rotationController.forward();
      }
    }

    widget.onPressed!();
  }

  @override
  Widget build(BuildContext context) {
    final canHover = prefersDesktopUi(context) && widget.onPressed != null;

    return MouseRegion(
      cursor: widget.onPressed != null
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      onEnter: canHover ? (_) => setState(() => _isHovered = true) : null,
      onExit: canHover ? (_) => setState(() => _isHovered = false) : null,
      child: AnimatedScale(
        scale: canHover && _isHovered ? 1.02 : 1.0,
        duration: AppMotion.instant,
        curve: AppMotion.standardCurve,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: RotationTransition(
            turns: widget.rotateOnTap
                ? _rotationAnimation
                : const AlwaysStoppedAnimation(0),
            child: FloatingActionButton(
              onPressed: _handleTap,
              backgroundColor: widget.backgroundColor,
              foregroundColor: widget.foregroundColor,
              tooltip: widget.tooltip,
              heroTag: widget.heroTag,
              child: Icon(widget.icon),
            ),
          ),
        ),
      ),
    );
  }
}
