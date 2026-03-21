import 'package:flutter/material.dart';

/// ゲージウィジェットの設定モデル。
/// 新しいゲージを追加する際はこのクラスを使って設定を作成する。
class GaugeConfig {
  final String label;
  final String unit;
  final double minValue;
  final double maxValue;

  /// この値以上で警告色に変わる（null = 警告なし）
  final double? warningThreshold;

  /// この値以上で危険色に変わる（null = 危険なし）
  final double? dangerThreshold;

  final Color normalColor;
  final Color warningColor;
  final Color dangerColor;

  /// ゲージの直径（px）
  final double size;

  /// 値表示のフォントサイズ
  final double valueFontSize;

  /// 小数点以下の桁数
  final int decimals;

  const GaugeConfig({
    required this.label,
    required this.unit,
    required this.minValue,
    required this.maxValue,
    this.warningThreshold,
    this.dangerThreshold,
    this.normalColor = const Color(0xFF4CAF50),
    this.warningColor = const Color(0xFFFF9800),
    this.dangerColor = const Color(0xFFF44336),
    this.size = 180,
    this.valueFontSize = 28,
    this.decimals = 0,
  });
}
