import 'package:flutter/material.dart';

/// A subtle, staggered dot pattern to give the background some texture.
class AuthPatternBackground extends StatelessWidget {
  const AuthPatternBackground({super.key, required this.color, required this.child});
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _PatternPainter(color: color),
          ),
        ),
        child,
      ],
    );
  }
}

class _PatternPainter extends CustomPainter {
  final Color color;

  _PatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.04) // Very faint!
      ..style = PaintingStyle.fill;

    const spacingX = 60.0;
    const spacingY = 60.0;
    
    int row = 0;
    // Draw far enough off-screen to ensure the edges are covered
    for (double y = -spacingY; y < size.height + spacingY; y += spacingY) {
      // Stagger every other row
      double offsetX = (row % 2 == 0) ? 0 : spacingX / 2;
      for (double x = -spacingX; x < size.width + spacingX; x += spacingX) {
        canvas.drawCircle(Offset(x + offsetX, y), 5, paint);
      }
      row++;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
