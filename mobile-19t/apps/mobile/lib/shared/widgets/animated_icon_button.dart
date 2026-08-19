import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_interaction.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/theme_color_presets.dart';

/// An IconButton with scale animation on tap, similar to Telegram.
///
/// Provides a more satisfying tap feedback compared to standard IconButton.
///
/// Example:
/// ```dart
/// AnimatedIconButton(
///   icon: Icons.search,
///   onPressed: () => _showSearch(),
///   tooltip: 'Search',
/// )
/// ```
class AnimatedIconButton extends StatefulWidget {
  const AnimatedIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.color,
    this.size,
    this.tooltip,
    this.enableHaptic = false,
    this.scaleDown = 0.88,
    this.padding = const EdgeInsets.all(8.0),
  });

  /// The icon to display
  final IconData icon;

  /// Called when the button is pressed
  final VoidCallback? onPressed;

  /// Color of the icon
  final Color? color;

  /// Size of the icon
  final double? size;

  /// Tooltip text
  final String? tooltip;

  /// Whether to trigger haptic feedback
  final bool enableHaptic;

  /// Scale factor when pressed
  final double scaleDown;

  /// Padding around the icon
  final EdgeInsets padding;

  @override
  State<AnimatedIconButton> createState() => _AnimatedIconButtonState();
}

class _AnimatedIconButtonState extends State<AnimatedIconButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );

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
    if (widget.onPressed != null) {
      _controller.forward();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    _controller.reverse();
  }

  void _handleTapCancel() {
    _controller.reverse();
  }

  void _handleTap() {
    if (widget.onPressed == null) return;

    if (widget.enableHaptic) {
      HapticFeedback.lightImpact();
    }

    widget.onPressed!();
  }

  @override
  Widget build(BuildContext context) {
    final canHover = prefersDesktopUi(context) && widget.onPressed != null;
    final palette = context.appPalette;
    final hoverBackground = palette.surfaceVariant.withValues(alpha: 0.75);

    final iconButton = GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: RepaintBoundary(
        child: AnimatedContainer(
          duration: AppMotion.instant,
          curve: AppMotion.standardCurve,
          decoration: BoxDecoration(
            color: canHover && _isHovered
                ? hoverBackground
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Padding(
              padding: widget.padding,
              child: Icon(widget.icon, color: widget.color, size: widget.size),
            ),
          ),
        ),
      ),
    );

    final wrapped = MouseRegion(
      cursor: widget.onPressed != null
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      onEnter: canHover ? (_) => setState(() => _isHovered = true) : null,
      onExit: canHover ? (_) => setState(() => _isHovered = false) : null,
      child: iconButton,
    );

    if (widget.tooltip != null) {
      return Tooltip(message: widget.tooltip!, child: wrapped);
    }

    return wrapped;
  }
}
