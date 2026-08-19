import 'package:flutter/material.dart';
import '../../../core/theme/theme_color_presets.dart';

class ChatAvatar extends StatelessWidget {
  const ChatAvatar({
    super.key,
    required this.displayName,
    this.imageUrl,
    this.isGroup = false,
    this.radius = 20,
    this.iconSize,
  });

  final String displayName;
  final String? imageUrl;
  final bool isGroup;
  final double radius;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return CircleAvatar(
      radius: radius,
      backgroundColor: palette.surfaceVariant,
      foregroundImage: imageUrl != null ? NetworkImage(imageUrl!) : null,
      child: isGroup
          ? Icon(
              Icons.group,
              color: palette.primary,
              size: iconSize ?? radius * 0.9,
            )
          : Text(
              _initials(displayName),
              style: TextStyle(
                color: palette.primary,
                fontWeight: FontWeight.w600,
                fontSize: radius * 0.55,
              ),
            ),
    );
  }

  String _initials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';

    final words = trimmed.split(RegExp(r'\s+'));
    if (words.length >= 2) {
      return '${words.first[0]}${words.last[0]}'.toUpperCase();
    }

    return words.first[0].toUpperCase();
  }
}
