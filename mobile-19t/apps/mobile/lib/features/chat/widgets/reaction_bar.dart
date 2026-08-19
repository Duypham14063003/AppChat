import 'package:flutter/material.dart';
import '../models/reaction_group.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_color_presets.dart';

class ReactionBar extends StatelessWidget {
  final List<ReactionGroup> reactions;
  final void Function(String emoji) onToggle;
  final void Function(List<ReactionGroup> reactions)? onShowDetails;

  const ReactionBar({
    super.key,
    required this.reactions,
    required this.onToggle,
    this.onShowDetails,
  });

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: reactions.map((group) {
          return _AnimatedReactionChip(
            key: ValueKey(group.emoji),
            group: group,
            onTap: () => onToggle(group.emoji),
            onLongPress: onShowDetails != null
                ? () => onShowDetails!(reactions)
                : null,
          );
        }).toList(),
      ),
    );
  }
}

class _AnimatedReactionChip extends StatefulWidget {
  final ReactionGroup group;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _AnimatedReactionChip({
    super.key,
    required this.group,
    required this.onTap,
    this.onLongPress,
  });

  @override
  State<_AnimatedReactionChip> createState() => _AnimatedReactionChipState();
}

class _AnimatedReactionChipState extends State<_AnimatedReactionChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  int _previousCount = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: AppMotion.medium, vsync: this);
    _scaleAnimation =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 0.92, end: 1.04), weight: 55),
          TweenSequenceItem(tween: Tween(begin: 1.04, end: 1.0), weight: 45),
        ]).animate(
          CurvedAnimation(parent: _controller, curve: AppMotion.enterCurve),
        );
    _previousCount = widget.group.count;
    _controller.forward(from: 0);
  }

  @override
  void didUpdateWidget(covariant _AnimatedReactionChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.group.count != _previousCount) {
      _previousCount = widget.group.count;
      _controller
        ..stop()
        ..forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _chipLabel() {
    final users = widget.group.users;
    if (users.isEmpty) return '${widget.group.count}';
    if (users.length <= 3) {
      return users.map((u) => _firstName(u.name)).join(', ');
    }
    return '${widget.group.count}';
  }

  static String _firstName(String name) {
    final parts = name.trim().split(' ');
    return parts.last;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final tooltipMessage = widget.group.users.map((u) => u.name).join(', ');

    Widget chipContent = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: widget.group.isMine
            ? AppColors.gold.withValues(alpha: 0.15)
            : palette.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: widget.group.isMine
            ? Border.all(color: AppColors.gold.withValues(alpha: 0.4), width: 1)
            : Border.all(color: palette.surfaceVariant, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.group.emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text(
            _chipLabel(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: widget.group.isMine
                  ? AppColors.gold
                  : palette.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    if (tooltipMessage.isNotEmpty) {
      chipContent = Tooltip(
        message: tooltipMessage,
        decoration: BoxDecoration(
          color: palette.isLight ? Colors.grey[900] : Colors.grey[100],
          borderRadius: BorderRadius.circular(6),
        ),
        textStyle: TextStyle(
          color: palette.isLight ? Colors.white : Colors.black,
          fontSize: 11,
        ),
        child: chipContent,
      );
    }

    return RepaintBoundary(
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: GestureDetector(
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          child: chipContent,
        ),
      ),
    );
  }
}
