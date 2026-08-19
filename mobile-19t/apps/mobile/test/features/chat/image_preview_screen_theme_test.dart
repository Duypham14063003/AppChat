import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nineteen_tech_app/core/theme/app_theme.dart';
import 'package:nineteen_tech_app/core/theme/theme_color_presets.dart';
import 'package:nineteen_tech_app/features/chat/screens/image_preview_screen.dart';

void main() {
  final lightPalette = AppThemePreset.ivorySlate.palette;

  testWidgets('image preview screen uses active light theme colors', (
    tester,
  ) async {
    final imageFile = _createTestImageFile();
    addTearDown(() {
      if (imageFile.existsSync()) {
        imageFile.deleteSync();
      }
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(AppThemePreset.ivorySlate),
        home: ImagePreviewScreen(images: [XFile(imageFile.path)]),
      ),
    );
    await tester.pumpAndSettle();
    final theme = Theme.of(tester.element(find.byType(ImagePreviewScreen)));

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, lightPalette.background);

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.backgroundColor, lightPalette.background);
    expect(appBar.foregroundColor, lightPalette.textPrimary);

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.style?.color, lightPalette.textPrimary);
    expect(textField.decoration?.hintStyle?.color, lightPalette.textHint);

    final sendButton = tester.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    );
    expect(sendButton.backgroundColor, lightPalette.primary);

    final sendIcon = tester.widget<Icon>(find.byIcon(Icons.send_rounded));
    expect(sendIcon.color, theme.colorScheme.onPrimary);
  });
}

File _createTestImageFile() {
  final file = File(
    '${Directory.systemTemp.path}/image-preview-theme-test.png',
  );
  file.writeAsBytesSync(base64Decode(_kTransparentPngBase64));
  return file;
}

const _kTransparentPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9WlH0f8AAAAASUVORK5CYII=';
