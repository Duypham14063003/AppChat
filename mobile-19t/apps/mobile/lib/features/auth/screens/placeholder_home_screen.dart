import 'package:flutter/material.dart';
import 'package:nineteen_tech_app/core/config/app_config.dart';
import 'package:nineteen_tech_app/core/theme/app_typography.dart';
import 'package:nineteen_tech_app/core/theme/theme_color_presets.dart';

class PlaceholderHomeScreen extends StatelessWidget {
  final String title;
  final String? subtitle;

  const PlaceholderHomeScreen({super.key, this.title = 'Home', this.subtitle});

  @override
  Widget build(BuildContext context) {
    const config = AppConfig.instance;
    final palette = context.appPalette;
    return Scaffold(
      appBar: AppBar(title: Text(title), centerTitle: true),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: AppTypography.headlineLarge.copyWith(
                color: palette.primary,
              ),
            ),
            const SizedBox(height: 8),
            if (subtitle != null) ...[
              Text(
                subtitle!,
                style: AppTypography.bodyMedium.copyWith(
                  color: palette.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
            ],
            Text(
              'Environment: ${config.env.toUpperCase()}',
              style: AppTypography.bodyMedium.copyWith(
                color: palette.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${config.appName}\n${config.apiUrl}',
              style: AppTypography.caption.copyWith(color: palette.textHint),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
