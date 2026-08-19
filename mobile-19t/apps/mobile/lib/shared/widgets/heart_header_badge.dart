import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/auth_notifier.dart';
import '../../core/theme/theme_color_presets.dart';

class HeartHeaderBadge extends ConsumerWidget {
  const HeartHeaderBadge({super.key, this.countLabel, this.compact = false});

  final String? countLabel;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.appPalette;
    const accent = Color(0xFFC78A12);
    final authState = ref.watch(authNotifierProvider);
    final points = authState.valueOrNull?.points;
    final resolvedCountLabel = countLabel ?? formatHeartPoints(points);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 7 : 8,
      ),
      decoration: BoxDecoration(
        // color: palette.surface,
        // borderRadius: BorderRadius.circular(999),
        // border: Border.all(
        //   color: accent.withValues(alpha: palette.isLight ? 0.28 : 0.42),
        // ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: palette.isLight ? 0.06 : 0.2),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.favorite_rounded,
            color: const Color(0xFFFF5B7F),
            size: compact ? 16 : 18,
          ),
          const SizedBox(width: 6),
          Text(
            resolvedCountLabel,
            style: TextStyle(
              color: accent,
              fontSize: compact ? 12 : 13,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }
}

String formatHeartPoints(int? points) {
  final safePoints = points ?? 0;
  final digits = safePoints.toString();
  final buffer = StringBuffer();

  for (var i = 0; i < digits.length; i++) {
    final remaining = digits.length - i;
    buffer.write(digits[i]);
    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write(',');
    }
  }

  return buffer.toString();
}
