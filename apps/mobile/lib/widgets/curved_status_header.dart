import 'dart:ui';

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
    this.backgroundImage,
    this.scroll,
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

  /// Top-right header control or status pill (e.g. harness battery).
  final Widget? trailing;

  /// Translucent info pills under the description.
  final List<Widget> chips;

  /// Optional background image URL to subtly blend behind the color gradient.
  final String? backgroundImage;
  final ScrollController? scroll;

  Widget _buildBackground(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (backgroundImage != null)
          Image.network(
            backgroundImage!,
            fit: BoxFit.cover,
          ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color.withValues(alpha: backgroundImage != null ? 0.7 : 1.0),
                color,
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final sheet = context.ff.bg;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Background image with fading gradient overlay
        scroll == null
            ? Positioned.fill(child: _buildBackground(context))
            : AnimatedBuilder(
                animation: scroll!,
                builder: (context, _) {
                  final offset = scroll!.hasClients ? scroll!.offset : 0.0;
                  // If overscrolled, offset is negative. We pull the top UP by the same
                  // amount so it anchors to the screen top, and it stretches down to the bottom.
                  final top = offset < 0 ? offset : 0.0;
                  return Positioned(
                    top: top,
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _buildBackground(context),
                  );
                },
              ),
        // Content
        SizedBox(
          width: double.infinity,
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
                  // The toolbar keeps the title centred when trailing is a
                  // pill wider than leading.
                  SizedBox(
                    height: 40,
                    child: NavigationToolbar(
                      leading: SizedBox(width: 40, height: 40, child: leading),
                      middle: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: FurFeelTokens.typeH3Size,
                        ),
                      ),
                      trailing: trailing,
                      middleSpacing: FurFeelTokens.space2,
                    ),
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
          const SizedBox(height: FurFeelTokens.space6),
          // Keeps the full curve's shape and crops the flat sheet beneath it,
          // so content sits close without flattening the arc.
          ClipRect(
            child: SizedBox(
              height: 56,
              width: double.infinity,
              child: OverflowBox(
                alignment: Alignment.topCenter,
                minHeight: 120,
                maxHeight: 120,
                child: CustomPaint(
                  size: const Size(double.infinity, 120),
                  painter: _CurvePainter(sheet),
                ),
              ),
            ),
          ),
        ],
      ),
        ),
      ],
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

/// Back control for pages with a [CurvedStatusHeader]: scrolls with the hero,
/// then sticks under the status bar so a pushed page can always go back. It
/// darkens as it sticks to stay readable on the sheet. Place it in a [Stack].
class StickyBackPill extends StatelessWidget {
  const StickyBackPill({super.key, required this.scroll, required this.onTap});

  final ScrollController scroll;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final restTop = padding.top + FurFeelTokens.space5;
    final stuckTop = padding.top + FurFeelTokens.space1;
    return AnimatedBuilder(
      animation: scroll,
      builder: (context, _) {
        final offset = scroll.hasClients ? scroll.offset : 0.0;
        final top = restTop - offset;
        final stuck = ((stuckTop - top) / 40).clamp(0.0, 1.0);
        return Positioned(
          top: top < stuckTop ? stuckTop : top,
          left: FurFeelTokens.space4,
          child: Tooltip(
            message: 'Back',
            child: Semantics(
              button: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: GlassPill(
                      color: Color.lerp(
                        Colors.white.withValues(alpha: 0.15),
                        Colors.black.withValues(alpha: 0.3),
                        stuck,
                      ),
                      child: const SizedBox(
                        height: 17,
                        child: Icon(
                          Icons.arrow_back_ios_new,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Frosted pill for controls over photos and the hero, matching
/// `StressPill(onDark: true)`. Pass a dark [color] where it can leave the hero.
class GlassPill extends StatelessWidget {
  const GlassPill({super.key, required this.child, this.color});

  final Widget child;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(FurFeelTokens.radiusPill),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: FurFeelTokens.space2,
            vertical: FurFeelTokens.space1,
          ),
          color: color ?? Colors.white.withValues(alpha: 0.15),
          child: child,
        ),
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
