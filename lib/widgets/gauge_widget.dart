import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/gauge_config.dart';

/// 再利用可能な自動車メーター風ゲージウィジェット。
/// [GaugeConfig] で表示設定を変更可能。
class GaugeWidget extends StatelessWidget {
  final GaugeConfig config;

  /// 表示する値。null の場合は "--" を表示。
  final double? value;

  const GaugeWidget({super.key, required this.config, this.value});

  @override
  Widget build(BuildContext context) {
    final displayColor = _getValueColor(value, config);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          config.label,
          style: const TextStyle(
            color: Color(0xFFB0BEC5),
            fontSize: 12,
            letterSpacing: 2,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: config.size,
          height: config.size,
          child: CustomPaint(
            painter: _GaugePainter(config: config, value: value),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      value != null
                          ? value!.toStringAsFixed(config.decimals)
                          : '--',
                      style: TextStyle(
                        color: displayColor,
                        fontSize: config.valueFontSize,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      config.unit,
                      style: const TextStyle(
                        color: Color(0xFF78909C),
                        fontSize: 11,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Color _getValueColor(double? value, GaugeConfig config) {
    if (value == null) return const Color(0xFF37474F);
    final dangerTh = config.dangerThreshold;
    final warnTh = config.warningThreshold;
    if (dangerTh != null && value >= dangerTh) return config.dangerColor;
    if (warnTh != null && value >= warnTh) return config.warningColor;
    return config.normalColor;
  }
}

class _GaugePainter extends CustomPainter {
  final GaugeConfig config;
  final double? value;

  // 150° スタート、240° スイープ（メーター風）
  static const double _startDeg = 150.0;
  static const double _sweepDeg = 240.0;
  static const double _startRad = _startDeg * math.pi / 180.0;
  static const double _sweepRad = _sweepDeg * math.pi / 180.0;

  const _GaugePainter({required this.config, this.value});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 12;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // 背景トラック
    canvas.drawArc(
      rect,
      _startRad,
      _sweepRad,
      false,
      Paint()
        ..color = const Color(0xFF1E272E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round,
    );

    _drawTicks(canvas, center, radius);

    if (value == null) return;

    final fraction =
        ((value! - config.minValue) / (config.maxValue - config.minValue))
            .clamp(0.0, 1.0);

    _drawValueArc(canvas, rect, fraction);
    _drawNeedle(canvas, center, radius, fraction);
  }

  void _drawValueArc(Canvas canvas, Rect rect, double fraction) {
    final warnFrac = config.warningThreshold != null
        ? ((config.warningThreshold! - config.minValue) /
                (config.maxValue - config.minValue))
            .clamp(0.0, 1.0)
        : 1.0;
    final dangerFrac = config.dangerThreshold != null
        ? ((config.dangerThreshold! - config.minValue) /
                (config.maxValue - config.minValue))
            .clamp(0.0, 1.0)
        : 1.0;

    void drawArcSegment(double start, double end, Color color) {
      if (end <= start) return;
      final drawEnd = math.min(fraction, end);
      if (drawEnd <= start) return;
      canvas.drawArc(
        rect,
        _startRad + start * _sweepRad,
        (drawEnd - start) * _sweepRad,
        false,
        Paint()
          ..color = color.withValues(alpha: 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14
          ..strokeCap = StrokeCap.round,
      );
    }

    drawArcSegment(0.0, warnFrac, config.normalColor);
    drawArcSegment(warnFrac, dangerFrac, config.warningColor);
    drawArcSegment(dangerFrac, 1.0, config.dangerColor);
  }

  void _drawNeedle(
      Canvas canvas, Offset center, double radius, double fraction) {
    final angle = _startRad + fraction * _sweepRad;
    final innerR = radius - 18;
    final tip = Offset(
      center.dx + innerR * math.cos(angle),
      center.dy + innerR * math.sin(angle),
    );
    final tail = Offset(
      center.dx + 8 * math.cos(angle + math.pi),
      center.dy + 8 * math.sin(angle + math.pi),
    );

    canvas.drawLine(
      tail,
      tip,
      Paint()
        ..color = Colors.white
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(center, 5, Paint()..color = _getColor(fraction));
  }

  void _drawTicks(Canvas canvas, Offset center, double radius) {
    const totalTicks = 12;
    for (int i = 0; i <= totalTicks; i++) {
      final angle = _startRad + (i / totalTicks) * _sweepRad;
      final isMajor = i % 3 == 0;
      final tickLen = isMajor ? 10.0 : 5.0;
      final outer = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      final inner = Offset(
        center.dx + (radius - tickLen) * math.cos(angle),
        center.dy + (radius - tickLen) * math.sin(angle),
      );
      canvas.drawLine(
        outer,
        inner,
        Paint()
          ..color =
              isMajor ? const Color(0xFF546E7A) : const Color(0xFF37474F)
          ..strokeWidth = isMajor ? 1.5 : 1.0,
      );
    }
  }

  Color _getColor(double fraction) {
    final warnFrac = config.warningThreshold != null
        ? (config.warningThreshold! - config.minValue) /
            (config.maxValue - config.minValue)
        : 1.0;
    final dangerFrac = config.dangerThreshold != null
        ? (config.dangerThreshold! - config.minValue) /
            (config.maxValue - config.minValue)
        : 1.0;
    if (fraction >= dangerFrac) return config.dangerColor;
    if (fraction >= warnFrac) return config.warningColor;
    return config.normalColor;
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.value != value || old.config != config;
}
