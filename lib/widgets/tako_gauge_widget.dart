import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── SVG coordinate space constants (viewBox 0 0 500 520) ──────────────────
const double _cx = 250, _cy = 218;
const double _gaugeR = 196;
const double _trackR = 186;
const double _headR = 70;
const double _needleR = 170;

double _deg(double d) => d * pi / 180;
Offset _polar(double deg, double r, {double ox = _cx, double oy = _cy}) =>
    Offset(ox + r * cos(_deg(deg)), oy + r * sin(_deg(deg)));
double _pctToAngle(double pct) => 135 + pct.clamp(0.0, 1.0) * 270;
double _sweep(double a0, double a1) => ((a1 - a0) + 360) % 360;

// ── Theme ─────────────────────────────────────────────────────────────────
class TakoTheme {
  final Color track;
  final Color headLight, headMid, headDark;
  final Color headHotLight, headHotMid, headHotDark;
  final Color body, spot;
  final Color beak, beakCrease, counterStroke;
  final Color aura, brow;
  final Color mouthOuter, mouthOuterStroke;

  const TakoTheme({
    required this.track,
    required this.headLight,
    required this.headMid,
    required this.headDark,
    required this.headHotLight,
    required this.headHotMid,
    required this.headHotDark,
    required this.body,
    required this.spot,
    required this.beak,
    required this.beakCrease,
    required this.counterStroke,
    required this.aura,
    required this.brow,
    required this.mouthOuter,
    required this.mouthOuterStroke,
  });

  static const red = TakoTheme(
    track: Color(0xFF22D3EE),
    headLight: Color(0xFFEE4444),
    headMid: Color(0xFFCC1A1A),
    headDark: Color(0xFF8A0A0A),
    headHotLight: Color(0xFFFF6060),
    headHotMid: Color(0xFFEE2020),
    headHotDark: Color(0xFFAA0A0A),
    body: Color(0xFFCC1A1A),
    spot: Color(0xFFE87030),
    beak: Color(0xFFF0921A),
    beakCrease: Color(0xFFB85A0A),
    counterStroke: Color(0xFF5B21B6),
    aura: Color(0x2EC81E1E),
    brow: Color(0xFF6A0808),
    mouthOuter: Color(0xFFC04820),
    mouthOuterStroke: Color(0xFF7A1C06),
  );
}

// ── Widget ────────────────────────────────────────────────────────────────
class TakoGaugeWidget extends StatefulWidget {
  final double? value;
  final double min, max, redline, limit;
  final String label, unit;
  final TakoTheme theme;
  final int majorStep, minorStep;
  final int labelDiv;
  final String? scaleLabel;

  const TakoGaugeWidget({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.redline,
    required this.limit,
    required this.label,
    required this.unit,
    required this.theme,
    required this.majorStep,
    required this.minorStep,
    this.labelDiv = 1,
    this.scaleLabel,
  });

  @override
  State<TakoGaugeWidget> createState() => _TakoGaugeWidgetState();
}

class _TakoGaugeWidgetState extends State<TakoGaugeWidget>
    with TickerProviderStateMixin {
  late final AnimationController _timeCtrl;
  late final AnimationController _blinkCtrl;

  @override
  void initState() {
    super.initState();
    _timeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
    _blinkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _timeCtrl.dispose();
    _blinkCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = (widget.value ?? widget.min).toDouble();
    final isRed = value >= widget.redline;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Gauge label
        Text(
          widget.label,
          style: GoogleFonts.orbitron(
            fontSize: 9,
            letterSpacing: 3,
            color: isRed ? const Color(0xFFEF4444) : const Color(0xFF2D4D70),
          ),
        ),
        const SizedBox(height: 6),
        // Gauge canvas
        Expanded(
          child: AnimatedBuilder(
            animation: Listenable.merge([_timeCtrl, _blinkCtrl]),
            builder: (context2, child2) => CustomPaint(
              painter: _TakoGaugePainter(
                value: value,
                min: widget.min,
                max: widget.max,
                redline: widget.redline,
                limit: widget.limit,
                theme: widget.theme,
                majorStep: widget.majorStep,
                minorStep: widget.minorStep,
                labelDiv: widget.labelDiv,
                scaleLabel: widget.scaleLabel,
                timePhase: _timeCtrl.value,
                blinkPhase: _blinkCtrl.value,
              ),
              size: Size.infinite,
            ),
          ),
        ),
        const SizedBox(height: 6),
        // Value readout
        _ValueReadout(value: value, unit: widget.unit, isRed: isRed),
      ],
    );
  }
}

class _ValueReadout extends StatelessWidget {
  final double value;
  final String unit;
  final bool isRed;

  const _ValueReadout({
    required this.value,
    required this.unit,
    required this.isRed,
  });

  @override
  Widget build(BuildContext context) {
    final color = isRed ? const Color(0xFFEF4444) : const Color(0xFFDDEEFF);
    return Column(
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: value.round().toString(),
                style: GoogleFonts.orbitron(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: color,
                  height: 1,
                  shadows: isRed
                      ? [Shadow(color: const Color(0xFFEF4444), blurRadius: 14)]
                      : null,
                ),
              ),
              TextSpan(
                text: ' $unit',
                style: GoogleFonts.orbitron(
                  fontSize: 13,
                  color: isRed
                      ? const Color(0x88EF4444)
                      : const Color(0xFF4A6E90),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Painter ───────────────────────────────────────────────────────────────
class _TakoGaugePainter extends CustomPainter {
  final double value, min, max, redline, limit;
  final TakoTheme theme;
  final int majorStep, minorStep, labelDiv;
  final String? scaleLabel;
  final double timePhase, blinkPhase;

  const _TakoGaugePainter({
    required this.value,
    required this.min,
    required this.max,
    required this.redline,
    required this.limit,
    required this.theme,
    required this.majorStep,
    required this.minorStep,
    this.labelDiv = 1,
    this.scaleLabel,
    required this.timePhase,
    required this.blinkPhase,
  });

  double get _pct => ((value - min) / (max - min)).clamp(0.0, 1.0);
  double get _pctRed => ((redline - min) / (max - min)).clamp(0.0, 1.0);
  bool get _isRed => value >= redline;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 500, size.height / 520);
    _drawBackground(canvas);
    _drawArcs(canvas);
    _drawTicks(canvas);
    if (scaleLabel != null) _drawScaleLabel(canvas);
    _drawTentacles(canvas);
    _drawHeadBack(canvas);
    _drawBeak(canvas);
    _drawFace(canvas);
    canvas.restore();
  }

  // ── Background ──────────────────────────────────────────────────────────
  void _drawBackground(Canvas canvas) {
    final center = const Offset(_cx, _cy);
    final r = _gaugeR + 12;
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: const [Color(0xFF0D1728), Color(0xFF050810)],
        ).createShader(Rect.fromCircle(center: center, radius: r)),
    );
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = const Color(0xFF0F1E30)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  // ── Arc track ───────────────────────────────────────────────────────────
  void _drawArcs(Canvas canvas) {
    final curA = _pctToAngle(_pct);
    final redA = _pctToAngle(_pctRed);
    final limA = _pctToAngle(((limit - min) / (max - min)).clamp(0.0, 1.0));
    final tRect = Rect.fromCircle(
      center: const Offset(_cx, _cy),
      radius: _trackR,
    );

    // Redline zone bg
    _arc(canvas, tRect, redA, _sweep(redA, 45), 16, const Color(0xFF4A0808));
    // Normal zone bg
    _arc(canvas, tRect, 135, redA - 135, 16, const Color(0xFF0E1E32));

    // Active fill (normal zone)
    if (_pct > 0.005) {
      _arc(
        canvas,
        tRect,
        135,
        (curA < redA ? curA : redA) - 135,
        13,
        theme.track,
        cap: StrokeCap.round,
        blur: 4,
      );
    }

    // Active fill (redline zone)
    if (_isRed) {
      final pulse = (sin(timePhase * pi * 10) + 1) / 2;
      final rc = Color.lerp(
        const Color(0xFFEF4444),
        const Color(0x88EF4444),
        pulse * 0.45,
      )!;
      _arc(
        canvas,
        tRect,
        redA,
        (curA < limA ? curA : limA) - redA,
        15,
        rc,
        cap: StrokeCap.round,
        blur: 6,
      );
    }

    // Outer / inner rings
    _arc(
      canvas,
      Rect.fromCircle(center: const Offset(_cx, _cy), radius: _gaugeR),
      135,
      270,
      2,
      const Color(0xFF162540),
    );
    _arc(
      canvas,
      Rect.fromCircle(center: const Offset(_cx, _cy), radius: _trackR - 10),
      135,
      270,
      1.5,
      const Color(0xFF0A1525),
    );
  }

  void _arc(
    Canvas canvas,
    Rect rect,
    double startDeg,
    double sweepDeg,
    double sw,
    Color color, {
    StrokeCap? cap,
    double blur = 0,
  }) {
    if (sweepDeg <= 0) return;
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw;
    if (cap != null) p.strokeCap = cap;
    if (blur > 0) p.maskFilter = MaskFilter.blur(BlurStyle.normal, blur);
    canvas.drawArc(rect, _deg(startDeg), _deg(sweepDeg), false, p);
  }

  // ── Tick marks ──────────────────────────────────────────────────────────
  void _drawTicks(Canvas canvas) {
    final range = (max - min).round();
    final steps = range ~/ minorStep;
    for (int i = 0; i <= steps; i++) {
      final v = min + i * minorStep;
      final pct = (v - min) / (max - min);
      final a = _pctToAngle(pct);
      final major = (i * minorStep) % majorStep == 0;
      final tickRed = v >= redline;
      final tickColor = tickRed
          ? const Color(0xFFF87171)
          : const Color(0xFF233550);

      canvas.drawLine(
        _polar(a, _gaugeR - (major ? 24 : 12)),
        _polar(a, _gaugeR - 2),
        Paint()
          ..color = tickColor
          ..strokeWidth = major ? 2.5 : 1.2,
      );

      if (major) {
        final label = labelDiv == 1
            ? v.round().toString()
            : (v.round() ~/ labelDiv).toString();
        final tp = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: tickColor,
              fontFamily: 'monospace',
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final pos = _polar(a, _gaugeR - 40);
        tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
      }
    }
  }

  // ── Scale label ─────────────────────────────────────────────────────────
  void _drawScaleLabel(Canvas canvas) {
    final tp = TextPainter(
      text: TextSpan(
        text: scaleLabel,
        style: const TextStyle(
          fontSize: 11,
          color: Color(0xFF1E3450),
          letterSpacing: 3,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(_cx - tp.width / 2, _cy + 150));
  }

  // ── Tentacles ────────────────────────────────────────────────────────────
  static const _tentacleCfg = [
    (32.0, 86.0, -1.0, 0.00),
    (48.0, 94.0, 1.0, 0.15),
    (65.0, 100.0, -1.0, 0.28),
    (82.0, 104.0, 1.0, 0.40),
    (99.0, 104.0, -1.0, 0.50),
    (116.0, 100.0, 1.0, 0.58),
    (133.0, 94.0, -1.0, 0.65),
    (149.0, 86.0, 1.0, 0.70),
  ];

  void _drawTentacles(Canvas canvas) {
    for (int i = 0; i < _tentacleCfg.length; i++) {
      final (a, len, curl, delay) = _tentacleCfg[i];
      final period = 1.4 + i * 0.18;
      final t = timePhase * 10;
      final wave = sin(2 * pi * ((t - delay) / period));
      final dx = 2.5 * wave;
      final dy = -2.0 * wave;
      final rot = _deg(2.0) * wave;

      final s = _polar(a, _headR * 0.9);
      final pA = a + 90;
      final p1 = Offset(
        s.dx + len * 0.40 * cos(_deg(a)) + curl * 20 * cos(_deg(pA)),
        s.dy + len * 0.40 * sin(_deg(a)) + curl * 20 * sin(_deg(pA)),
      );
      final p2 = Offset(
        s.dx + len * 0.75 * cos(_deg(a)) - curl * 12 * cos(_deg(pA)),
        s.dy + len * 0.75 * sin(_deg(a)) - curl * 12 * sin(_deg(pA)),
      );
      final e = Offset(s.dx + len * cos(_deg(a)), s.dy + len * sin(_deg(a)));

      canvas.save();
      canvas.translate(s.dx, s.dy);
      canvas.rotate(rot);
      canvas.translate(dx - s.dx, dy - s.dy);

      // Body
      canvas.drawPath(
        Path()
          ..moveTo(s.dx, s.dy)
          ..cubicTo(p1.dx, p1.dy, p2.dx, p2.dy, e.dx, e.dy),
        Paint()
          ..color = theme.body
          ..style = PaintingStyle.stroke
          ..strokeWidth = 22
          ..strokeCap = StrokeCap.round,
      );

      // Tip curl
      final curlAng = a + curl * 70;
      final tip2 = Offset(
        e.dx + 22 * cos(_deg(curlAng)),
        e.dy + 22 * sin(_deg(curlAng)),
      );
      canvas.drawPath(
        Path()
          ..moveTo(e.dx, e.dy)
          ..quadraticBezierTo(
            tip2.dx,
            tip2.dy,
            (e.dx + tip2.dx) / 2,
            (e.dy + tip2.dy) / 2,
          ),
        Paint()
          ..color = theme.body
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14
          ..strokeCap = StrokeCap.round,
      );

      // Suction spots
      for (final t in [0.28, 0.54, 0.78]) {
        final mt = 1 - t;
        final spot = Offset(
          mt * mt * mt * s.dx +
              3 * mt * mt * t * p1.dx +
              3 * mt * t * t * p2.dx +
              t * t * t * e.dx,
          mt * mt * mt * s.dy +
              3 * mt * mt * t * p1.dy +
              3 * mt * t * t * p2.dy +
              t * t * t * e.dy,
        );
        canvas.drawCircle(spot, 9, Paint()..color = theme.spot);
      }

      canvas.restore();
    }
  }

  // ── Head ────────────────────────────────────────────────────────────────
  void _drawHeadBack(Canvas canvas) {
    const center = Offset(_cx, _cy);
    final pulse = (sin(timePhase * pi * 10) + 1) / 2;

    // Aura
    final auraColor = _isRed
        ? Color.lerp(const Color(0x59DC1E1E), const Color(0x20DC1E1E), pulse)!
        : theme.aura;
    canvas.drawCircle(
      center,
      _headR + 20,
      Paint()
        ..color = auraColor
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Drop shadow
    canvas.drawCircle(
      const Offset(_cx, _cy + 4),
      _headR,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Head gradient
    final hL = _isRed ? theme.headHotLight : theme.headLight;
    final hM = _isRed ? theme.headHotMid : theme.headMid;
    final hD = _isRed ? theme.headHotDark : theme.headDark;
    canvas.drawCircle(
      center,
      _headR,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.16, -0.3),
          radius: 0.7,
          colors: [hL, hM, hD],
          stops: const [0.0, 0.6, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: _headR)),
    );

    // Highlight streak
    canvas.drawPath(
      Path()
        ..moveTo(_cx - 55, _cy - 28)
        ..quadraticBezierTo(_cx - 42, _cy - 72, _cx + 10, _cy - 68),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round,
    );
  }

  // ── Beak needle ─────────────────────────────────────────────────────────
  void _drawBeak(Canvas canvas) {
    final a = _pctToAngle(_pct);
    final aR = _deg(a);
    final pR = _deg(a + 90);
    final tip = Offset(_cx + _needleR * cos(aR), _cy + _needleR * sin(aR));
    const bw = 17.0;
    final bL = Offset(_cx + bw * cos(pR), _cy + bw * sin(pR));
    final bR = Offset(_cx - bw * cos(pR), _cy - bw * sin(pR));
    final fwd = _needleR * 0.55;
    const puff = 12.0;
    final cL = Offset(
      bL.dx + fwd * cos(aR) + puff * cos(pR),
      bL.dy + fwd * sin(aR) + puff * sin(pR),
    );
    final cR = Offset(
      bR.dx + fwd * cos(aR) - puff * cos(pR),
      bR.dy + fwd * sin(aR) - puff * sin(pR),
    );
    final back = Offset(_cx - 30 * cos(aR), _cy - 30 * sin(aR));

    final beakColor = _isRed ? const Color(0xFFFCA5A5) : theme.beak;
    final beakPath = Path()
      ..moveTo(bL.dx, bL.dy)
      ..quadraticBezierTo(cL.dx, cL.dy, tip.dx, tip.dy)
      ..quadraticBezierTo(cR.dx, cR.dy, bR.dx, bR.dy)
      ..close();

    // Glow
    canvas.drawPath(
      beakPath,
      Paint()
        ..color = beakColor
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, _isRed ? 6 : 5),
    );
    // Fill
    canvas.drawPath(beakPath, Paint()..color = beakColor);
    canvas.drawCircle(
      tip,
      6,
      Paint()
        ..color = beakColor
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, _isRed ? 6 : 5),
    );

    // Crease
    canvas.drawPath(
      Path()
        ..moveTo(bL.dx, bL.dy)
        ..quadraticBezierTo(
          _cx + _needleR * 0.25 * cos(aR),
          _cy + _needleR * 0.25 * sin(aR),
          bR.dx,
          bR.dy,
        ),
      Paint()
        ..color = (_isRed ? const Color(0xFFDC4444) : theme.beakCrease)
            .withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Counter weight
    canvas.drawCircle(back, 13, Paint()..color = const Color(0xFF1A0A30));
    canvas.drawCircle(
      back,
      13,
      Paint()
        ..color = _isRed ? const Color(0xFFCC1A1A) : theme.counterStroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  // ── Face ────────────────────────────────────────────────────────────────
  void _drawFace(Canvas canvas) {
    final a = _pctToAngle(_pct);
    final aR = _deg(a);
    final pdx = cos(aR) * 5;
    final pdy = sin(aR) * 5;
    final browRaise = _pct > 0.7 ? (_pct - 0.7) * 30 : 0.0;
    final blush = ((_pct - 0.4) / 0.55).clamp(0.0, 0.55);

    // Eyebrows
    final browPaint = Paint()
      ..color = theme.brow
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(_cx - 40, _cy - 40 - browRaise)
        ..quadraticBezierTo(
          _cx - 26,
          _cy - 50 - browRaise,
          _cx - 14,
          _cy - 42 - browRaise,
        ),
      browPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(_cx + 14, _cy - 42 - browRaise)
        ..quadraticBezierTo(
          _cx + 26,
          _cy - 50 - browRaise,
          _cx + 40,
          _cy - 40 - browRaise,
        ),
      browPaint,
    );

    // Eye blink: 85-100% of blinkPhase (4s cycle)
    double eyeScaleY = 1.0;
    if (blinkPhase > 0.85) {
      final bt = (blinkPhase - 0.85) / 0.15;
      eyeScaleY = bt < 0.4
          ? 1.0 - 0.95 * (bt / 0.4)
          : 0.05 + 0.95 * ((bt - 0.4) / 0.6);
    }

    _drawEye(canvas, _cx - 24, _cy - 26, 16, eyeScaleY, pdx * 0.5, pdy * 0.5);
    _drawEye(canvas, _cx + 24, _cy - 26, 16, eyeScaleY, pdx * 0.5, pdy * 0.5);

    // Eye shine
    canvas.drawCircle(
      Offset(_cx - 30 + pdx * 0.25, _cy - 33 + pdy * 0.25),
      4.5,
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );
    canvas.drawCircle(
      Offset(_cx + 18 + pdx * 0.25, _cy - 33 + pdy * 0.25),
      4.5,
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );
    canvas.drawCircle(
      Offset(_cx - 20 + pdx * 0.25, _cy - 18 + pdy * 0.25),
      2,
      Paint()..color = Colors.white.withValues(alpha: 0.45),
    );
    canvas.drawCircle(
      Offset(_cx + 28 + pdx * 0.25, _cy - 18 + pdy * 0.25),
      2,
      Paint()..color = Colors.white.withValues(alpha: 0.45),
    );

    // Blush
    if (blush > 0) {
      final bp = Paint()
        ..color = const Color(0xFFF87171).withValues(alpha: blush * 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(Offset(_cx - 42, _cy - 8), 14, bp);
      canvas.drawCircle(Offset(_cx + 42, _cy - 8), 14, bp);
    }

    // Mouth
    canvas.drawCircle(
      const Offset(_cx, _cy),
      20,
      Paint()..color = theme.mouthOuter,
    );
    canvas.drawCircle(
      const Offset(_cx, _cy),
      20,
      Paint()
        ..color = theme.mouthOuterStroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(
      const Offset(_cx, _cy),
      12,
      Paint()..color = const Color(0xFF3A0804),
    );
    canvas.drawPath(
      Path()
        ..moveTo(_cx - 11, _cy - 10)
        ..quadraticBezierTo(_cx, _cy - 13, _cx + 11, _cy - 10),
      Paint()
        ..color = const Color(0xFF7F4A3A).withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawEye(
    Canvas canvas,
    double ex,
    double ey,
    double r,
    double scaleY,
    double pdx,
    double pdy,
  ) {
    canvas.save();
    canvas.translate(ex, ey);
    canvas.scale(1.0, scaleY);
    canvas.translate(-ex, -ey);
    canvas.drawCircle(
      Offset(ex, ey),
      r,
      Paint()..color = const Color(0xFF140404),
    );
    canvas.drawCircle(
      Offset(ex + pdx, ey + pdy),
      9,
      Paint()..color = const Color(0xFF0A0202),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TakoGaugePainter old) =>
      old.value != value ||
      old.timePhase != timePhase ||
      old.blinkPhase != blinkPhase;
}
