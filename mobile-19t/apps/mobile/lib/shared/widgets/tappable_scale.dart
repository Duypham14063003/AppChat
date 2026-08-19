import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_interaction.dart';
import '../../core/theme/app_motion.dart';

/// A widget that scales down when tapped, creating a Telegram-like press effect.
///
/// Wraps any widget and adds a subtle scale animation on tap. The widget scales
/// down to [scaleDown] (default 0.96) when pressed and springs back when released.
///
/// Example:
/// ```dart
/// TappableScale(
///   onTap: () => print('Tapped!'),
///   child: Container(
///     padding: EdgeInsets.all(16),
///     child: Text('Tap me'),
///   ),
/// )
/// ```
class TappableScale extends StatefulWidget {
  const TappableScale({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scaleDown = 0.96,
    this.duration = const Duration(milliseconds: 100),
    this.enableHaptic = false,
    this.enabled = true,
    this.hoverScale = 1.0,
    this.showClickCursor = true,
  });

  /// The widget to apply the scale animation to
  final Widget child;

  /// Called when the user taps the widget
  final VoidCallback? onTap;

  /// Called when the user long-presses the widget
  final VoidCallback? onLongPress;

  /// The scale factor when pressed (0.96 = 96% of original size)
  final double scaleDown;

  /// Animation duration for scale transition
  final Duration duration;

  /// Whether to trigger haptic feedback on tap
  final bool enableHaptic;

  /// Whether the widget is enabled for interaction
  final bool enabled;

  /// The scale factor when hovered on desktop-like platforms.
  final double hoverScale;

  /// Whether to show a click cursor on hover.
  final bool showClickCursor;

  @override
  State<TappableScale> createState() => _TappableScaleState();
}

class _TappableScaleState extends State<TappableScale>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);

    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.scaleDown).animate(
      CurvedAnimation(
        parent: _controller,
        curve: AppMotion.standardCurve,
        reverseCurve: AppMotion.enterCurve,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (!widget.enabled) return;
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    if (!widget.enabled) return;
    _controller.reverse();
  }

  void _handleTapCancel() {
    if (!widget.enabled) return;
    _controller.reverse();
  }

  void _handleTap() {
    if (!widget.enabled || widget.onTap == null) return;

    if (widget.enableHaptic) {
      HapticFeedback.lightImpact();
    }

    widget.onTap!();
  }

  void _handleLongPress() {
    if (!widget.enabled || widget.onLongPress == null) return;

    if (widget.enableHaptic) {
      HapticFeedback.mediumImpact();
    }

    widget.onLongPress!();
  }

  @override
  Widget build(BuildContext context) {
    final canHover = prefersDesktopUi(context) && widget.enabled;
    final hoverScale = canHover && _isHovered ? widget.hoverScale : 1.0;
    final cursor = widget.showClickCursor && widget.enabled
        ? SystemMouseCursors.click
        : MouseCursor.defer;

    return MouseRegion(
      cursor: cursor,
      onEnter: canHover ? (_) => setState(() => _isHovered = true) : null,
      onExit: canHover ? (_) => setState(() => _isHovered = false) : null,
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onTap: _handleTap,
        onLongPress: widget.onLongPress != null ? _handleLongPress : null,
        behavior: HitTestBehavior.opaque,
        child: RepaintBoundary(
          child: AnimatedScale(
            scale: hoverScale,
            duration: AppMotion.instant,
            curve: AppMotion.standardCurve,
            child: ScaleTransition(scale: _scaleAnimation, child: widget.child),
          ),
        ),
      ),
    );
  }
}
