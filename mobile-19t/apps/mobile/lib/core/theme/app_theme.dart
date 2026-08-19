import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_typography.dart';
import 'theme_color_presets.dart';

abstract final class AppTheme {
  static ThemeData dark([AppThemePreset preset = AppThemePreset.noirGold]) {
    final palette = preset.palette;
    final base = palette.isLight ? ThemeData.light() : ThemeData.dark();

    return base.copyWith(
      brightness: palette.isLight ? Brightness.light : Brightness.dark,
      scaffoldBackgroundColor: palette.background,
      extensions: <ThemeExtension<dynamic>>[
        AppThemePaletteExtension(palette: palette),
      ],
      colorScheme:
          (palette.isLight
                  ? const ColorScheme.light()
                  : const ColorScheme.dark())
              .copyWith(
                primary: palette.primary,
                onPrimary: palette.background,
                secondary: palette.primaryLight,
                surface: palette.surface,
                onSurface: palette.textPrimary,
                error: AppColors.danger,
              ),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        foregroundColor: palette.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: palette.isLight
            ? SystemUiOverlayStyle.dark.copyWith(
                statusBarColor: Colors.transparent,
                statusBarBrightness: Brightness.light,
              )
            : SystemUiOverlayStyle.light.copyWith(
                statusBarColor: Colors.transparent,
                statusBarBrightness: Brightness.dark,
              ),
        titleTextStyle: AppTypography.titleLarge.copyWith(
          color: palette.textPrimary,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.surface,
        indicatorColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final color = states.contains(WidgetState.selected)
              ? palette.primary
              : palette.textSecondary;
          return AppTypography.labelMedium.copyWith(color: color);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final color = states.contains(WidgetState.selected)
              ? palette.primary
              : palette.textSecondary;
          return IconThemeData(color: color);
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: palette.surface,
        indicatorColor: palette.primary.withValues(alpha: 0.16),
        selectedIconTheme: IconThemeData(color: palette.primary),
        unselectedIconTheme: IconThemeData(color: palette.textSecondary),
        selectedLabelTextStyle: AppTypography.labelLarge.copyWith(
          color: palette.textPrimary,
        ),
        unselectedLabelTextStyle: AppTypography.labelLarge.copyWith(
          color: palette.textSecondary,
        ),
      ),
      cardTheme: CardThemeData(color: palette.card, elevation: 0),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.primary,
          foregroundColor: palette.isLight ? Colors.white : palette.background,
          textStyle: AppTypography.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.textPrimary,
          side: BorderSide(color: palette.surfaceVariant),
          textStyle: AppTypography.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.primary,
          textStyle: AppTypography.labelLarge,
        ),
      ),
      textTheme: TextTheme(
        headlineLarge: AppTypography.headlineLarge.copyWith(
          color: palette.textPrimary,
        ),
        headlineMedium: AppTypography.headlineMedium.copyWith(
          color: palette.textPrimary,
        ),
        headlineSmall: AppTypography.headlineSmall.copyWith(
          color: palette.textPrimary,
        ),
        titleLarge: AppTypography.titleLarge.copyWith(
          color: palette.textPrimary,
        ),
        titleMedium: AppTypography.titleMedium.copyWith(
          color: palette.textPrimary,
        ),
        titleSmall: AppTypography.titleSmall.copyWith(
          color: palette.textPrimary,
        ),
        bodyLarge: AppTypography.bodyLarge.copyWith(color: palette.textPrimary),
        bodyMedium: AppTypography.bodyMedium.copyWith(
          color: palette.textSecondary,
        ),
        bodySmall: AppTypography.bodySmall.copyWith(
          color: palette.textSecondary,
        ),
        labelLarge: AppTypography.labelLarge.copyWith(
          color: palette.textPrimary,
        ),
        labelMedium: AppTypography.labelMedium.copyWith(
          color: palette.textSecondary,
        ),
        labelSmall: AppTypography.labelSmall.copyWith(color: palette.textHint),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surfaceVariant,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.surfaceVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.primary, width: 1.4),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        hintStyle: AppTypography.bodyMedium.copyWith(color: palette.textHint),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      dividerColor: palette.surfaceVariant,
      iconTheme: IconThemeData(color: palette.textSecondary),
    );
  }
}
