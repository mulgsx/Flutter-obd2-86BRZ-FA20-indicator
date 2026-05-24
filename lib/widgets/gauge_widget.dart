import 'package:flutter/material.dart';
import '../models/gauge_config.dart';
import '../theme/app_colors.dart';

/// Simple OBD2 digital readout card — wide horizontal card with label and value.
/// シンプルなOBD2デジタル表示カード。横長カードにラベルと値を並べる。
class GaugeWidget extends StatelessWidget {
  final GaugeConfig config;

  /// Value to display. Shows "--" when null.
  /// 表示する値。null の場合は "--" を表示。
  final double? value;

  const GaugeWidget({super.key, required this.config, this.value});

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(value, config);
    final valueText = value != null
        ? value!.toStringAsFixed(config.decimals)
        : '--';

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

  Color _statusColor(double? value, GaugeConfig config) {
    if (value == null) return AppColors.gaugeNull;
    return config.normalColor;
  }
}
