import 'package:flutter/material.dart';

abstract final class AppColors {
  // -- Background --
  static const background     = Colors.white;
  static const surface        = Color(0xFFF5F5F5); // cards, bars, dialogs
  static const border         = Color(0xFFE0E0E0); // dividers, outlines

  // -- Accent --
  static const primary        = Color(0xFF1976D2); // Material Blue 700
  static const primaryVariant = Color(0xFF1565C0); // Material Blue 800

  // -- Text --
  static const textPrimary    = Colors.black;
  static const textSecondary  = Colors.black87;
  static const textTertiary   = Colors.black54;
  static const textDisabled   = Colors.black38;
  static const textMuted      = Colors.black26;

  // -- Status --
  static const success        = Color(0xFF4CAF50);
  static const warning        = Color(0xFFFF9800);
  static const danger         = Color(0xFFF44336);
  static const errorLight     = Color(0xFFF85149); // log ERROR row
  // Colors.red.shade400 / .shade700 left as-is (standard Material names)

  // -- Debug log --
  static const logText        = Color(0xFF546E7A); // dark blue-gray

  // -- Gauge --
  static const gaugeLabel     = Color(0xFF546E7A); // label text
  static const gaugeUnit      = Color(0xFF78909C); // unit text
  static const gaugeNull      = Colors.black38;    // no-data display
  static const gaugeTrack     = Color(0xFFEEEEEE); // background arc
  static const gaugeMajorTick = Color(0xFF90A4AE); // long tick marks
  static const gaugeMinorTick = Color(0xFFB0BEC5); // short tick marks
  static const gaugeNeedle    = Colors.black87;
}
