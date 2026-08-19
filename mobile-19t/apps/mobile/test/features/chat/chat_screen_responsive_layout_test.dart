import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nineteen_tech_app/core/theme/app_theme.dart';
import 'package:nineteen_tech_app/features/chat/screens/chat_screen.dart';

void main() {
  group('chat responsive frame helpers', () {
    test(
      'enables wide conversation framing only when pane is large enough',
      () {
        expect(shouldUseWideConversationFrame(680), isFalse);
        expect(shouldUseWideConversationFrame(720), isTrue);
        expect(shouldUseWideConversationFrame(1080), isTrue);
      },
    );
  });

  group('ChatConversationFrame', () {
    testWidgets('bounds wide conversation content to the shared frame width', (
      tester,
    ) async {
      _setTestViewport(tester, const Size(1600, 900));
      await tester.pumpWidget(
        _buildHarness(
          width: 1400,
          height: 300,
          child: ChatConversationFrame(
            availableWidth: 1400,
            child: Container(key: const Key('frame-child'), height: 48),
          ),
        ),
      );

      final childSize = tester.getSize(find.byKey(const Key('frame-child')));
      expect(childSize.width, closeTo(wideConversationFrameMaxWidth, 0.1));
    });

    testWidgets(
      'preserves narrow conversation width below the desktop threshold',
      (tester) async {
        _setTestViewport(tester, const Size(700, 900));
        await tester.pumpWidget(
          _buildHarness(
            width: 640,
            height: 300,
            child: ChatConversationFrame(
              availableWidth: 640,
              child: Container(key: const Key('frame-child'), height: 48),
            ),
          ),
        );

        final childSize = tester.getSize(find.byKey(const Key('frame-child')));
        expect(childSize.width, closeTo(640, 0.1));
      },
    );

    testWidgets('can expand wide chat surfaces to the full frame height', (
      tester,
    ) async {
      _setTestViewport(tester, const Size(1600, 900));
      await tester.pumpWidget(
        _buildHarness(
          width: 1400,
          height: 260,
          child: ChatConversationFrame(
            availableWidth: 1400,
            expand: true,
            child: Container(key: const Key('expand-child')),
          ),
        ),
      );

      final childSize = tester.getSize(find.byKey(const Key('expand-child')));
      expect(childSize.width, closeTo(wideConversationFrameMaxWidth, 0.1));
      expect(childSize.height, closeTo(260, 0.1));
    });
  });
}

void _setTestViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _buildHarness({
  required double width,
  required double height,
  required Widget child,
}) {
  return MaterialApp(
    theme: AppTheme.dark(),
    home: Scaffold(
      body: Center(
        child: SizedBox(width: width, height: height, child: child),
      ),
    ),
  );
}
