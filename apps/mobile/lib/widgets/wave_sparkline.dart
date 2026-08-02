import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A smooth waveform sparkline — a curved line with a soft fill beneath
/// (docs/22 v6 mood board). Used on the Home health-overview rows, one per
/// metric in that metric's colour. Self-hides below [minPoints] readings.
class WaveSparkline extends StatelessWidget {
  const WaveSparkline({
    super.key,
    required this.series,
    required this.color,
    this.height = 42,
    this.minPoints = 2,
    this.strokeWidth = 2.4,
    this.fillOpacity = 0.12,
  });

  /// Readings oldest→newest. Denser series read as a richer wave.
  final List<double> series;
  final Color color;
  final double height;
  final int minPoints;
  final double strokeWidth;
  final double fillOpacity;

  @override
  Widget build(BuildContext context) {
    if (series.length < minPoints) return SizedBox(height: height);
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _WavePainter(series, color, strokeWidth, fillOpacity),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter(this.series, this.color, this.strokeWidth, this.fillOpacity);

  final List<double> series;
  final Color color;
  final double strokeWidth;
  final double fillOpacity;

  static const _pad = 3.0;

  @override
  void paint(Canvas canvas, Size size) {
    final mn = series.reduce(math.min);
    final mx = series.reduce(math.max);
    final range = (mx - mn) == 0 ? 1.0 : (mx - mn);
    final pts = [
      for (var i = 0; i < series.length; i++)
        Offset(
          series.length == 1 ? 0 : i / (series.length - 1) * size.width,
          _pad + (1 - (series[i] - mn) / range) * (size.height - 2 * _pad),
        ),
    ];

    // Catmull-Rom → cubic Bézier for a smooth curve through the points.
    final line = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 0; i < pts.length - 1; i++) {
      final p0 = i > 0 ? pts[i - 1] : pts[i];
      final p1 = pts[i];
      final p2 = pts[i + 1];
      final p3 = i + 2 < pts.length ? pts[i + 2] : pts[i + 1];
      final c1 = Offset(p1.dx + (p2.dx - p0.dx) / 6, p1.dy + (p2.dy - p0.dy) / 6);
      final c2 = Offset(p2.dx - (p3.dx - p1.dx) / 6, p2.dy - (p3.dy - p1.dy) / 6);
      line.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }

    final fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..color = color.withValues(alpha: fillOpacity)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      old.color != color ||
      old.fillOpacity != fillOpacity ||
      !identical(old.series, series);
}
