import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_colors.dart';

class TypingIndicator extends StatefulWidget {
  final List<String> typingUserIds;
  final bool isGroup;
  final String? currentUserId;
  final Map<String, Map<String, String?>> members;

  const TypingIndicator({
    super.key,
    required this.typingUserIds,
    required this.isGroup,
    this.currentUserId,
    this.members = const {},
  });

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1100),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _getUserName(String userId) {
    return widget.members[userId]?['name'] ?? 'User';
  }
  // TYPING_INDICATOR_BUILD_PLACEHOLDER

  @override
  Widget build(BuildContext context) {
    final filtered = widget.typingUserIds
        .where((id) => id != widget.currentUserId)
        .toList();
    if (filtered.isEmpty) return const SizedBox.shrink();

    String text;
    if (!widget.isGroup) {
      text = 'đang nhập';
    } else if (filtered.length == 1) {
      text = '${_getUserName(filtered[0])} đang nhập';
    } else if (filtered.length <= 3) {
      text = '${filtered.map(_getUserName).join(', ')} đang nhập';
    } else {
      text = '${filtered.length} người đang nhập';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Text(
            text,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(width: 4),
          _AnimatedDots(controller: _controller),
        ],
      ),
    );
  }
}

class _AnimatedDots extends StatelessWidget {
  final AnimationController controller;

  const _AnimatedDots({required this.controller});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDot(0.0),
              const SizedBox(width: 4),
              _buildDot(0.2),
              const SizedBox(width: 4),
              _buildDot(0.4),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDot(double offset) {
    final phase = (controller.value + offset) % 1.0;
    final envelope = math.sin(phase * math.pi);
    final lift = Curves.easeOut.transform(envelope.clamp(0.0, 1.0));
    final fade = AppMotion.standardCurve.transform(envelope.clamp(0.0, 1.0));

    return Transform.translate(
      offset: Offset(0, -3.0 * lift),
      child: Transform.scale(
        scale: 0.84 + (0.2 * lift),
        child: Opacity(
          opacity: 0.35 + (0.65 * fade),
          child: Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppColors.textSecondary,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}
