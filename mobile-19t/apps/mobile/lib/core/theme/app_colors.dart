import 'package:flutter/material.dart';

abstract final class AppColors {
  // Gold variants
  static const Color gold = Color(0xFFC9A84C);
  static const Color goldLight = Color(0xFFE2C06A);
  static const Color goldDark = Color(0xFFA8843A);
  static const Color goldPale = Color(0xFFF5E4A8);

  // Dark background hierarchy
  static const Color background = Color(0xFF0A0A0A);
  static const Color surface = Color(0xFF141418);
  static const Color surfaceVariant = Color(0xFF1E1E24);
  static const Color card = Color(0xFF28282F);

  // Text colors
  static const Color textPrimary = Color(0xFFF2EDD8);
  static const Color textSecondary = Color(0xFF9E9880);
  static const Color textHint = Color(0xFF7A7568);

  // Chat bubble
  static const Color bubbleMine = Color(0xFF2A2210);

  // Sender name colors for group chats (Telegram-style, 8-color palette)
  static const List<Color> senderColors = [
    Color(0xFFE57373), // red
    Color(0xFF81C784), // green
    Color(0xFF64B5F6), // blue
    Color(0xFFFFB74D), // orange
    Color(0xFFBA68C8), // purple
    Color(0xFF4DD0E1), // cyan
    Color(0xFFF06292), // pink
    Color(0xFFAED581), // lime
  ];

  // Semantic colors
  static const Color online = Color(0xFF2ECC71);
  static const Color danger = Color(0xFFE74C3C);
  static const Color warning = Color(0xFFF39C12);
  static const Color info = Color(0xFF3498DB);
}
