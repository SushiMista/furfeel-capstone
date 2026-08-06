import 'package:flutter/material.dart';

import '../theme/furfeel_tokens.dart';

/// The immersive full-bleed header (docs/22): a status/metric-coloured top with
/// a header row (leading/title/trailing translucent controls), a mark, a big
/// value, a bold description, chips, and a wide curved divider that sweeps edge
/// to edge into the sheet content below. The colour runs a soft top→bottom
/// gradient so it eases into the divider.
///
/// Reused by the main screen (status colour, classification word) and each
/// vital detail (metric colour, the value). Colour carries meaning here — it
/// pairs with the word, never rides alone (docs/19 §9).
class CurvedStatusHeader extends StatelessWidget {
  const CurvedStatusHeader({
    super.key,
    required this.color,
    required this.title,
    required this.mark,
    required this.value,
    required this.description,
    this.unit,
    this.leading,
    this.trailing,
    this.chips = const [],
  });

  /// Full-bleed background colour (status ramp or metric colour).
  final Color color;

  /// Small centred label in the header row, e.g. "FurFeel score".
  final String title;

  /// Icon shown above the value (paw for the score, the metric icon on detail).
  final IconData mark;

  /// The hero value — the classification word ("Calm") or a number ("95").
  final String value;

  /// Small unit beside a numeric value ("bpm"). Null for a word value.
  final String? unit;

  /// One bold line under the value.
  final String description;

  /// Top-left header control (a paw mark, or a back button on pushed screens).
  final Widget? leading;

  /// Top-right header control (e.g. settings).
  final Widget? trailing;

  /// Translucent info pills under the description.
  final List<Widget> chips;

  @override
  Widget build(BuildContext context) {
    final sheet = context.ff.bg;
    return Container(
      width: double.infinity,
      // Vertical gradient: fullest at the top, easing lighter toward the curve.
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color, Color.lerp(color, Colors.white, 0.16)!],
        ),
      ),
      child: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(FurFeelTokens.space4,
                  FurFeelTokens.space5, FurFeelTokens.space4, 0),
              child: Column(
                children: [
                  // Header row: leading · title · trailing.
                  Row(
                    children: [
                      SizedBox(width: 40, height: 40, child: leading),
                      Expanded(
                        child: Text(
                          title,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: FurFeelTokens.typeH3Size,
                          ),
                        ),
                      ),
                      SizedBox(width: 40, height: 40, child: trailing),
                    ],
                  ),
                  const SizedBox(height: FurFeelTokens.space5),
                  Icon(mark, color: Colors.white, size: 40),
                  const SizedBox(height: FurFeelTokens.space3),
                  // Big value + optional unit. FittedBox keeps it on one line
                  // even at large text scale (a11y).
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text.rich(
                      TextSpan(
                        text: value,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 60,
                          height: 1,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                        children: [
                          if (unit != null)
                            TextSpan(
                              text: ' $unit',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: Colors.white70,
                              ),
                            ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(height: FurFeelTokens.space2),
                  Text(
                    description,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: FurFeelTokens.typeBodyMobileSize,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (chips.isNotEmpty) ...[
                    const SizedBox(height: FurFeelTokens.space4),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: FurFeelTokens.space2,
                      runSpacing: FurFeelTokens.space2,
                      children: chips,
                    ),
                  ],
                ],
              ),
            ),
          ),
          // The wide edge-to-edge curve.
          const SizedBox(height: FurFeelTokens.space5),
          ClipRect(
            child: CustomPaint(
              size: const Size(double.infinity, 56),
              painter: _CurvePainter(sheet),
            ),
          ),
        ],
      ),
    );
  }
}

/// A translucent white pill for the header (icon + label).
class HeaderChip extends StatelessWidget {
  const HeaderChip({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(FurFeelTokens.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: FurFeelTokens.typeCaptionSize,
                  fontWeight: FontWeight.w300)),
        ],
      ),
    );
  }
}

/// Round translucent header control (paw / back / settings), matching the
/// mood-board buttons. A null [onTap] renders a plain (decorative) disc.
class HeaderCircleButton extends StatelessWidget {
  const HeaderCircleButton(
      {super.key, required this.icon, this.onTap, this.tooltip});

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: Colors.white.withValues(alpha: 0.22),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: 18, color: Colors.white),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

class _CurvePainter extends CustomPainter {
  _CurvePainter(this.sheet);

  final Color sheet;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // Endpoints run well past both edges (clipped) so only the smooth wide
    // middle shows — no straight/cut ends.
    final path = Path()
      ..moveTo(-0.61 * w, h)
      ..cubicTo(0.083 * w, -0.03 * h, 0.917 * w, -0.03 * h, 1.61 * w, h)
      ..close();
    canvas.drawPath(path, Paint()..color = sheet);
  }

  @override
  bool shouldRepaint(_CurvePainter old) => old.sheet != sheet;
}
