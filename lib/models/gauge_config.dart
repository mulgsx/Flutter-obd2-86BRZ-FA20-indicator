import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Configuration model for the gauge widget.
/// Use this class to create settings when adding a new gauge.
/// ゲージウィジェットの設定モデル。
/// 新しいゲージを追加する際はこのクラスを使って設定を作成する。
class GaugeConfig {
  final String label;
  final String unit;
  final double minValue;
  final double maxValue;

  /// Switches to warning color at or above this value (null = no warning).
  /// この値以上で警告色に変わる（null = 警告なし）
  final double? warningThreshold;

  /// Switches to danger color at or above this value (null = no danger).
  /// この値以上で危険色に変わる（null = 危険なし）
  final double? dangerThreshold;

  final Color normalColor;
  final Color warningColor;
  final Color dangerColor;

  /// Gauge diameter in pixels / ゲージの直径（px）
  final double size;

  /// Font size for the value display / 値表示のフォントサイズ
  final double valueFontSize;

  /// Number of decimal places / 小数点以下の桁数
  final int decimals;

  const GaugeConfig({
    required this.label,
    required this.unit,
    required this.minValue,
    required this.maxValue,
    this.warningThreshold,
    this.dangerThreshold,
    this.normalColor = AppColors.success,
    this.warningColor = AppColors.warning,
    this.dangerColor = AppColors.danger,
    this.size = 180,
    this.valueFontSize = 28,
    this.decimals = 0,
  });
}
