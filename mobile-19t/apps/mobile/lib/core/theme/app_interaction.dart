import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

bool prefersDesktopUi(BuildContext context) {
  final platform = Theme.of(context).platform;
  return kIsWeb ||
      platform == TargetPlatform.macOS ||
      platform == TargetPlatform.windows ||
      platform == TargetPlatform.linux;
}

ScrollPhysics appScrollPhysics(BuildContext context) {
  if (prefersDesktopUi(context)) {
    return const ClampingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
  }

  return const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
}

class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
    PointerDeviceKind.unknown,
  };

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    if (!prefersDesktopUi(context)) {
      return child;
    }

    return Scrollbar(
      controller: details.controller,
      thumbVisibility: false,
      interactive: true,
      child: child,
    );
  }
}
