import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_colors.dart';

class SwipeToReply extends StatefulWidget {
  final Widget child;
  final VoidCallback onReply;
  final bool enabled;

  const SwipeToReply({
    super.key,
    required this.child,
    required this.onReply,
    this.enabled = true,
  });

  @override
  State<SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<SwipeToReply>
    with SingleTickerProviderStateMixin {
  late AnimationController _dragController;
  bool _didTriggerHaptic = false;

  @override
  void initState() {
    super.initState();
    _dragController = AnimationController(
      vsync: this,
      duration: AppMotion.fast,
      lowerBound: 0,
      upperBound: 88,
    );
  }

  @override
  void dispose() {
    _dragController.dispose();
    super.dispose();
  }

  void _snapBack([double velocity = 0]) {
    final simulation = SpringSimulation(
      const SpringDescription(mass: 0.9, stiffness: 420, damping: 30),
      _dragController.value,
      0,
      -velocity / 1000,
    );
    _dragController.animateWith(simulation);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: (details) {
        _dragController.stop();
        final newValue = (_dragController.value + details.delta.dx).clamp(
          0.0,
          _dragController.upperBound,
        );
        _dragController.value = newValue;

        if (newValue >= 60 && !_didTriggerHaptic) {
          _didTriggerHaptic = true;
          HapticFeedback.lightImpact();
        } else if (newValue < 60) {
          _didTriggerHaptic = false;
        }
      },
      onHorizontalDragEnd: (details) {
        if (_dragController.value >= 60) {
          widget.onReply();
        }
        _snapBack(details.primaryVelocity ?? 0);
        _didTriggerHaptic = false;
      },
      onHorizontalDragCancel: () {
        _snapBack();
        _didTriggerHaptic = false;
      },
      child: AnimatedBuilder(
        animation: _dragController,
        builder: (context, child) {
          final dragX = _dragController.value;
          final progress = (dragX / 60).clamp(0.0, 1.0);
          return Stack(
            clipBehavior: Clip.none,
            children: [
              if (dragX > 0)
                Positioned(
                  left: 4,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Transform.translate(
                      offset: Offset(10 * (1 - progress), 0),
                      child: Opacity(
                        opacity: 0.18 + (0.82 * progress),
                        child: Transform.scale(
                          scale: 0.78 + (0.22 * progress),
                          child: Icon(
                            Icons.reply,
                            color: dragX >= 60
                                ? AppColors.gold
                                : AppColors.textSecondary,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              Transform.translate(
                offset: Offset(dragX, 0),
                child: widget.child,
              ),
            ],
          );
        },
      ),
    );
  }
}
