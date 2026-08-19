import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nineteen_tech_app/features/chat/screens/chat_screen.dart';

void main() {
  group('chat keyboard dismiss helpers', () {
    test('dismisses composer focus only for drag-based list scroll starts', () {
      expect(
        shouldDismissComposerOnMessageListDrag(hasDragDetails: true),
        isTrue,
      );
      expect(
        shouldDismissComposerOnMessageListDrag(hasDragDetails: false),
        isFalse,
      );
    });

    test('screen taps only dismiss composer focus outside composer bounds', () {
      const composerBounds = Rect.fromLTWH(20, 600, 360, 72);

      expect(
        shouldDismissComposerOnScreenTap(
          globalPosition: const Offset(120, 630),
          composerBounds: composerBounds,
        ),
        isFalse,
      );
      expect(
        shouldDismissComposerOnScreenTap(
          globalPosition: const Offset(120, 540),
          composerBounds: composerBounds,
        ),
        isTrue,
      );
      expect(
        shouldDismissComposerOnScreenTap(
          globalPosition: const Offset(120, 540),
          composerBounds: null,
        ),
        isTrue,
      );
    });
  });
}
