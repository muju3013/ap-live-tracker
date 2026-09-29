import 'package:flutter/material.dart';

abstract class AppMotion {
  // Durations
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration normal = Duration(milliseconds: 240);
  static const Duration medium = Duration(milliseconds: 320);
  static const Duration slow = Duration(milliseconds: 450);

  // Curves
  static const Curve standard = Curves.easeInOutCubic;
  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve springy = Curves.easeOutBack;

  /// Helper to check if reduced motion is requested by user environment
  static bool isReducedMotion(BuildContext context) {
    return MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  }

  /// Get effective duration considering reduced motion
  static Duration getEffectiveDuration(BuildContext context, Duration baseDuration) {
    return isReducedMotion(context) ? Duration.zero : baseDuration;
  }
}
