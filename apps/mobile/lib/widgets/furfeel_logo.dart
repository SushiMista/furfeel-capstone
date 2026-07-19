import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/furfeel_tokens.dart';

/// FurFeel brand identity widget.
///
/// Two modes:
/// - [FurFeelLogo.inline] (default, [axis] = horizontal): the existing small
///   paw + wordmark row used in app bars and compact spots.
/// - [FurFeelLogo.auth] ([axis] = vertical): tall version for auth screens —
///   gradient paw pill, two-tone wordmark, optional tagline, staggered
///   entrance animation.
///
/// [size] controls the icon/text base size; spacing scales proportionally.
class FurFeelLogo extends StatelessWidget {
  /// Horizontal inline variant (app bar, compact spots).
  const FurFeelLogo({super.key, this.size = 20})
      : axis = Axis.horizontal,
        animate = false,
        showTagline = false;

  /// Vertical auth-screen variant with gradient pill + entrance animation.
  const FurFeelLogo.auth({
    super.key,
    this.size = 52,
    this.animate = true,
    this.showTagline = false,
  }) : axis = Axis.vertical;

  final double size;
  final Axis axis;
  final bool animate;
  final bool showTagline;

  @override
  Widget build(BuildContext context) {
    if (axis == Axis.horizontal) return _buildInline(context);
    return _buildAuth(context);
  }

  // ── Inline (app-bar) variant ─────────────────────────────────────────────
  Widget _buildInline(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.pets, size: size, color: context.ff.brand),
        SizedBox(width: size * 0.4),
        Text(
          'FurFeel',
          style: TextStyle(
            fontSize: size,
            fontWeight: FontWeight.w800,
            color: context.ff.brandInk,
          ),
        ),
      ],
    );
  }

  // ── Auth (vertical, animated) variant ───────────────────────────────────
  Widget _buildAuth(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;
    final textTheme = Theme.of(context).textTheme;

    final containerSize = size * 1.7;

    Widget paw = Container(
      width: containerSize,
      height: containerSize,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [context.ff.brand, context.ff.brandStrong],
        ),
        borderRadius: BorderRadius.circular(containerSize * 0.28),
        boxShadow: [
          BoxShadow(
            color: context.ff.brand.withValues(alpha: 0.30),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Icon(Icons.pets, size: size * 0.68, color: Colors.white),
    );

    if (animate && !reduce) {
      paw = paw
          .animate()
          .scale(
            begin: const Offset(0.55, 0.55),
            end: const Offset(1, 1),
            duration: 480.ms,
            curve: Curves.easeOutBack,
          )
          .fadeIn(duration: 280.ms);
    }

    Widget wordmark = RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        children: [
          TextSpan(
            text: 'Fur',
            style: textTheme.headlineMedium?.copyWith(
              color: context.ff.brandInk,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          TextSpan(
            text: 'Feel',
            style: textTheme.headlineMedium?.copyWith(
              color: context.ff.brand,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );

    if (animate && !reduce) {
      wordmark = wordmark
          .animate(delay: 100.ms)
          .fadeIn(duration: 340.ms, curve: Curves.easeOut)
          .slideY(begin: 0.08, end: 0, duration: 340.ms, curve: Curves.easeOut);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        paw,
        const SizedBox(height: 14),
        wordmark,
        if (showTagline) ...[
          const SizedBox(height: 6),
          Text(
            'Know how your dog is feeling',
            style: textTheme.bodySmall?.copyWith(
              color: context.ff.inkMuted,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ],
    );
  }
}
