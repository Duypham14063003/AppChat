import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemePreset { noirGold, forestCopper, oceanAmber, ivorySlate, zaloBlue }

class AppThemePalette {
  const AppThemePalette({
    required this.name,
    required this.description,
    required this.isLight,
    required this.primary,
    required this.primaryLight,
    required this.primaryDark,
    required this.primaryPale,
    required this.backgroundTop,
    required this.background,
    required this.backgroundBottom,
    required this.surface,
    required this.surfaceVariant,
    required this.card,
    required this.textPrimary,
    required this.textSecondary,
    required this.textHint,
  });

  final String name;
  final String description;
  final bool isLight;
  final Color primary;
  final Color primaryLight;
  final Color primaryDark;
  final Color primaryPale;
  final Color backgroundTop;
  final Color background;
  final Color backgroundBottom;
  final Color surface;
  final Color surfaceVariant;
  final Color card;
  final Color textPrimary;
  final Color textSecondary;
  final Color textHint;
}

@immutable
class AppThemePaletteExtension
    extends ThemeExtension<AppThemePaletteExtension> {
  const AppThemePaletteExtension({required this.palette});

  final AppThemePalette palette;

  @override
  AppThemePaletteExtension copyWith({AppThemePalette? palette}) {
    return AppThemePaletteExtension(palette: palette ?? this.palette);
  }

  @override
  AppThemePaletteExtension lerp(
    ThemeExtension<AppThemePaletteExtension>? other,
    double t,
  ) {
    if (other is! AppThemePaletteExtension) {
      return this;
    }
    return t < 0.5 ? this : other;
  }
}

const appThemePalettes = <AppThemePreset, AppThemePalette>{
  AppThemePreset.noirGold: AppThemePalette(
    name: 'Noir Gold',
    description: 'Tông đen vàng hiện tại, đậm và sang.',
    isLight: false,
    primary: Color(0xFFC9A84C),
    primaryLight: Color(0xFFE2C06A),
    primaryDark: Color(0xFFA8843A),
    primaryPale: Color(0xFFF5E4A8),
    backgroundTop: Color(0xFF16120A),
    background: Color(0xFF0A0A0A),
    backgroundBottom: Color(0xFF090909),
    surface: Color(0xFF141418),
    surfaceVariant: Color(0xFF1E1E24),
    card: Color(0xFF28282F),
    textPrimary: Color(0xFFF2EDD8),
    textSecondary: Color(0xFF9E9880),
    textHint: Color(0xFF7A7568),
  ),
  AppThemePreset.forestCopper: AppThemePalette(
    name: 'Forest Copper',
    description: 'Xanh rêu và đồng, dịu mắt hơn cho màn tối.',
    isLight: false,
    primary: Color(0xFFB88A44),
    primaryLight: Color(0xFFD3A766),
    primaryDark: Color(0xFF8B6631),
    primaryPale: Color(0xFFEAD7B0),
    backgroundTop: Color(0xFF0F1815),
    background: Color(0xFF09100E),
    backgroundBottom: Color(0xFF07100D),
    surface: Color(0xFF111A17),
    surfaceVariant: Color(0xFF1A2621),
    card: Color(0xFF22312B),
    textPrimary: Color(0xFFEAF0E8),
    textSecondary: Color(0xFF93A296),
    textHint: Color(0xFF6E7A71),
  ),
  AppThemePreset.oceanAmber: AppThemePalette(
    name: 'Ocean Amber',
    description: 'Navy đậm với amber sáng để tạo tương phản rõ.',
    isLight: false,
    primary: Color(0xFFFFB44D),
    primaryLight: Color(0xFFFFC975),
    primaryDark: Color(0xFFCC8525),
    primaryPale: Color(0xFFFFE0B3),
    backgroundTop: Color(0xFF0B1320),
    background: Color(0xFF070C14),
    backgroundBottom: Color(0xFF060A12),
    surface: Color(0xFF0F1824),
    surfaceVariant: Color(0xFF162335),
    card: Color(0xFF1D2D44),
    textPrimary: Color(0xFFF3F6FA),
    textSecondary: Color(0xFF98A9BC),
    textHint: Color(0xFF708297),
  ),
  AppThemePreset.ivorySlate: AppThemePalette(
    name: 'Ivory Slate',
    description: 'Nền trắng sáng, slate dịu và accent vàng ấm.',
    isLight: true,
    primary: Color(0xFFB7872E),
    primaryLight: Color(0xFFD8A94C),
    primaryDark: Color(0xFF8A651F),
    primaryPale: Color(0xFFF5E3B8),
    backgroundTop: Color(0xFFFFFEFB),
    background: Color(0xFFF7F5F0),
    backgroundBottom: Color(0xFFF0ECE4),
    surface: Color(0xFFFFFFFF),
    surfaceVariant: Color(0xFFE9E4DA),
    card: Color(0xFFF4F0E8),
    textPrimary: Color(0xFF1F2937),
    textSecondary: Color(0xFF5B6472),
    textHint: Color(0xFF8A92A1),
  ),
  AppThemePreset.zaloBlue: AppThemePalette(
    name: 'Zalo Blue',
    description: 'Nền sáng chủ đạo xanh dương, phong cách thanh thoát.',
    isLight: true,
    primary: Color(0xFF0068FF), // Zalo Blue
    primaryLight: Color(0xFF4D94FF),
    primaryDark: Color(0xFF0052CC),
    primaryPale: Color(0xFFE5F0FF),
    backgroundTop: Color(0xFFFFFFFF),
    background: Color(0xFFFFFFFF),
    backgroundBottom: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    surfaceVariant: Color(0xFFF4F5F7), // Light gray for chat backgrounds
    card: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF111111),
    textSecondary: Color(0xFF757575),
    textHint: Color(0xFFAAAAAA),
  ),
};

extension AppThemePresetX on AppThemePreset {
  AppThemePalette get palette => appThemePalettes[this]!;
}

extension AppThemeContextX on BuildContext {
  AppThemePalette get appPalette =>
      Theme.of(this).extension<AppThemePaletteExtension>()!.palette;
}

final themePresetProvider =
    NotifierProvider<ThemePresetController, AppThemePreset>(
      ThemePresetController.new,
    );

class ThemePresetController extends Notifier<AppThemePreset> {
  static const _storageKey = 'theme_preset';
  bool _loaded = false;

  @override
  AppThemePreset build() {
    if (!_loaded) {
      _loaded = true;
      Future<void>.microtask(_loadSavedPreset);
    }
    return AppThemePreset.ivorySlate;
  }

  Future<void> setPreset(AppThemePreset preset) async {
    if (state == preset) return;
    state = preset;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, preset.name);
  }

  Future<void> _loadSavedPreset() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_storageKey);
    if (saved == null) return;

    final preset = AppThemePreset.values.where((item) => item.name == saved);
    if (preset.isEmpty) return;

    final next = preset.first;
    if (state != next) {
      state = next;
    }
  }
}
