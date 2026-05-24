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
    this.normalColor = AppColors.success,
    this.warningColor = AppColors.warning,
    this.dangerColor = AppColors.danger,
    this.size = 180,
    this.valueFontSize = 36,
    this.decimals = 0,
  });
}
