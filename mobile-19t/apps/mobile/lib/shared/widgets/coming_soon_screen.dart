import 'package:flutter/material.dart';
import '../../core/theme/theme_color_presets.dart';

class ComingSoonScreen extends StatelessWidget {
  final IconData icon;
  final String title;

  const ComingSoonScreen({super.key, required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: palette.textHint),
            const SizedBox(height: 16),
            Text(
              'Tính năng đang phát triển',
              style: TextStyle(color: palette.textSecondary, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Coming soon',
              style: TextStyle(color: palette.textHint, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
