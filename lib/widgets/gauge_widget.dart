import 'package:flutter/material.dart';
import '../models/gauge_config.dart';
import '../theme/app_colors.dart';

/// The visual layer for a single OBD gauge — this file is responsible for
/// ALL rendering. Layout, colors, font sizes, and null handling live here.
///
/// Receives a [GaugeConfig] (what to show) and a [value] (the OBD reading).
/// It does not know about BLE, PIDs, or parsing — those are in OBDController.
///
/// 1ゲージの描画レイヤー — レイアウト・色・フォントサイズ・null処理はすべてここ。
/// [GaugeConfig]（表示設定）と [value]（OBD計測値）を受け取って描画する。
/// BLE・PID・解析の知識は持たない。
class GaugeWidget extends StatelessWidget {
  final GaugeConfig config;

  /// Live OBD reading to display.
  /// 表示するOBD計測値。
  final double? value;

  const GaugeWidget({super.key, required this.config, this.value});

  @override
  Widget build(BuildContext context) {
    // Shows "--" when null (not yet received).
    // null のとき（未受信）は "--" を表示する。
    final valueText = value != null
        ? value!.toStringAsFixed(config.decimals)
        : '--';

    // Simple card layout: label on top, value + unit on the bottom row.
    // シンプルなカード表示: 上にラベル、下の行に値と単位を並べる。
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              config.label,
              style: const TextStyle(
                color: AppColors.gaugeLabel,
                fontSize: 13,
                letterSpacing: 2,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  valueText,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: config.valueFontSize,
                    fontWeight: FontWeight.bold,
                    height: 1.0,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  config.unit,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: config.valueFontSize,
                    fontWeight: FontWeight.bold,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
