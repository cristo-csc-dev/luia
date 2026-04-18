import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

class LuiaSaveIcon extends StatefulWidget {
  const LuiaSaveIcon({
    super.key,
    this.size = 24,
    this.color = Colors.white,
    required this.trigger, // cambia el valor para relanzar animación
  });

  final double size;
  final Color color;
  final int trigger;

  @override
  State<LuiaSaveIcon> createState() => _LuiaSaveIconState();
}

class _LuiaSaveIconState extends State<LuiaSaveIcon> with TickerProviderStateMixin {
  late final AnimationController _strokeCtrl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 180));
  late final AnimationController _sparkCtrl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 160));

  @override
  void didUpdateWidget(covariant LuiaSaveIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != oldWidget.trigger) {
      _play();
    }
  }

  Future<void> _play() async {
    _strokeCtrl.stop();
    _sparkCtrl.stop();
    _strokeCtrl.value = 0;
    _sparkCtrl.value = 0;

    await _strokeCtrl.forward();
    // pequeño retraso para que sea "finisher"
    await Future.delayed(const Duration(milliseconds: 20));
    if (mounted) await _sparkCtrl.forward();
  }

  @override
  void dispose() {
    _strokeCtrl.dispose();
    _sparkCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_strokeCtrl, _sparkCtrl]),
      builder: (_, __) => CustomPaint(
        size: Size.square(widget.size),
        painter: _LuiaSavePainter(
          strokeT: _strokeCtrl.value,
          sparkT: _sparkCtrl.value,
          color: widget.color,
        ),
      ),
    );
  }
}

class _LuiaSavePainter extends CustomPainter {
  _LuiaSavePainter({required this.strokeT, required this.sparkT, required this.color});

  final double strokeT; // 0..1
  final double sparkT;  // 0..1
  final Color color;

  double _easeOutCubic(double t) => 1 - math.pow(1 - t, 3).toDouble();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // --------- Path de la "L" (ajústalo para que coincida con tu logo) ----------
    // Start abajo-izquierda -> sube -> corta a derecha (gesto tipo swoosh-L)
    final start = Offset(w * 0.30, h * 0.78);
    final mid   = Offset(w * 0.50, h * 0.20);
    final end   = Offset(w * 0.82, h * 0.58);

    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(w * 0.36, h * 0.48, mid.dx, mid.dy)
      ..quadraticBezierTo(w * 0.58, h * 0.40, end.dx, end.dy);

    final paintStroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.12 // grueso para que sea nítido a 24px
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final metric = path.computeMetrics().first;
    final t = _easeOutCubic(strokeT);
    final drawn = metric.extractPath(0, metric.length * t);
    canvas.drawPath(drawn, paintStroke);

    // Punto final del trazo
    final endPoint = _pointAlongMetric(metric, metric.length * t);

    // --------- Destello final (flash + ring + 2 partículas) ----------
    if (sparkT <= 0) return;

    final st = sparkT;

    // Flash opacidad (sube y baja rápido)
    final flashIn = (st / 0.35).clamp(0.0, 1.0);
    final flashOut = ((1 - st) / 0.65).clamp(0.0, 1.0);
    final flashOpacity = (flashIn * flashOut).clamp(0.0, 1.0);

    // Flash sparkle
    final flashScale = lerpDouble(0.7, 1.1, _easeOutCubic(flashIn))!;
    _drawSparkle(
      canvas,
      center: endPoint,
      radius: w * 0.18 * flashScale,
      paint: Paint()
        ..color = color.withOpacity(0.9 * flashOpacity)
        ..style = PaintingStyle.fill,
    );

    // Ring
    final ringT = ((st - 0.12) / 0.65).clamp(0.0, 1.0);
    if (ringT > 0) {
      final r = lerpDouble(w * 0.08, w * 0.22, _easeOutCubic(ringT))!;
      final ringOpacity = (1 - ringT) * 0.35;
      final ringPaint = Paint()
        ..color = color.withOpacity(ringOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.04;
      canvas.drawCircle(endPoint, r, ringPaint);
    }

    // 2 partículas
    final pT = ((st - 0.20) / 0.80).clamp(0.0, 1.0);
    if (pT > 0) {
      final dist = lerpDouble(w * 0.08, w * 0.24, _easeOutCubic(pT))!;
      final pOpacity = (1 - pT) * 0.55;
      final pPaint = Paint()..color = color.withOpacity(pOpacity);

      final a1 = -math.pi * 0.62; // arriba-izquierda
      final a2 = -math.pi * 0.38; // arriba-derecha

      canvas.drawCircle(
        endPoint + Offset(math.cos(a1) * dist, math.sin(a1) * dist),
        w * 0.045,
        pPaint,
      );
      canvas.drawCircle(
        endPoint + Offset(math.cos(a2) * dist, math.sin(a2) * dist),
        w * 0.038,
        pPaint,
      );
    }
  }

  void _drawSparkle(Canvas canvas, {required Offset center, required double radius, required Paint paint}) {
    final r = radius;
    final p = Path()
      ..moveTo(center.dx, center.dy - r)
      ..quadraticBezierTo(center.dx + r * 0.35, center.dy - r * 0.35, center.dx + r, center.dy)
      ..quadraticBezierTo(center.dx + r * 0.35, center.dy + r * 0.35, center.dx, center.dy + r)
      ..quadraticBezierTo(center.dx - r * 0.35, center.dy + r * 0.35, center.dx - r, center.dy)
      ..quadraticBezierTo(center.dx - r * 0.35, center.dy - r * 0.35, center.dx, center.dy - r)
      ..close();
    canvas.drawPath(p, paint);
  }

  Offset _pointAlongMetric(PathMetric metric, double d) {
    final t = metric.getTangentForOffset(d);
    return t?.position ?? Offset.zero;
  }

  @override
  bool shouldRepaint(covariant _LuiaSavePainter oldDelegate) =>
      oldDelegate.strokeT != strokeT || oldDelegate.sparkT != sparkT || oldDelegate.color != color;
}