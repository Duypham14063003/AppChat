import 'package:flutter/material.dart';
import 'package:nineteen_tech_app/core/theme/theme_color_presets.dart';

const _logo19TAssetPath = 'assets/Images/logo_19t.png';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 120,
              height: 120,
              child: Image.asset(_logo19TAssetPath, fit: BoxFit.contain),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: palette.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
