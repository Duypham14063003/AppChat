import 'package:flutter/animation.dart';

class AppMotion {
  const AppMotion._();

  static const Duration instant = Duration(milliseconds: 120);
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration medium = Duration(milliseconds: 240);
  static const Duration slow = Duration(milliseconds: 320);

  // Fast deceleration for enter transitions.
  static const Curve enterCurve = Cubic(0.16, 1.0, 0.3, 1.0);

  // Controlled acceleration for dismiss and reverse transitions.
  static const Curve exitCurve = Cubic(0.7, 0.0, 0.84, 0.0);

  // General-purpose curve for subtle UI state changes.
  static const Curve standardCurve = Cubic(0.2, 0.0, 0.0, 1.0);
}
