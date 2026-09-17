import 'dart:math' as math;
import 'package:flutter/material.dart';

class CandleSparkline extends StatelessWidget {
  const CandleSparkline({
    super.key,
    required this.series,
    required this.color,
    this.height = 42,
  });

  final List<double> series;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (series.length < 2) return SizedBox(height: height);
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _CandlePainter(series, color),
      ),
    );
  }
}

class _CandlePainter extends CustomPainter {
  _CandlePainter(this.series, this.color);
  final List<double> series;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (series.isEmpty) return;
    
    final mn = series.reduce(math.min);
    final mx = series.reduce(math.max);
    final range = (mx - mn) == 0 ? 1.0 : (mx - mn);
    
    final barCount = series.length;
    final totalUnits = barCount + (barCount - 1) * 0.5;
    final barWidth = math.max(3.0, size.width / totalUnits);
    final gap = barWidth * 0.5;
    
    final maxIndex = series.indexOf(mx);

    for (var i = 0; i < series.length; i++) {
      final val = series[i];
      final normalized = (val - mn) / range;
      final barHeight = math.max(barWidth, normalized * (size.height - barWidth) + barWidth);
      
      final x = i * (barWidth + gap);
      final y = size.height - barHeight;
      
      final rect = Rect.fromLTWH(x, y, barWidth, barHeight);
      final rrect = RRect.fromRectAndRadius(rect, Radius.circular(barWidth / 2));
      
      // Paint with a gradient instead of a solid color
      final isPeak = i == maxIndex;
      final paint = Paint()
        ..style = PaintingStyle.fill
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            isPeak ? color : color.withValues(alpha: 0.6),
            color.withValues(alpha: 0.0), // fade to completely transparent at the bottom
          ],
        ).createShader(rect);
        
      canvas.drawRRect(rrect, paint);
    }
  }

  @override
  bool shouldRepaint(_CandlePainter old) =>
      old.color != color || !identical(old.series, series);
}
