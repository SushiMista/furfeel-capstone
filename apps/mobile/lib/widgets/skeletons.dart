import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/furfeel_tokens.dart';
import '../util/motion.dart';

/// ADDED: shimmer skeletons shaped like the real cards (docs/19 §5a — never a
/// bare spinner). Shimmer stops under reduced motion; the shapes still show.
class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    Widget shimmer(Widget child) {
      if (context.reduceMotion) return child;
      return child
          .animate(onPlay: (c) => c.repeat())
          .shimmer(duration: 1200.ms, color: FurFeelTokens.surface);
    }

    Widget block({double? width, double height = 14, double radius = 6}) =>
        Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: FurFeelTokens.surfaceAlt,
            borderRadius: BorderRadius.circular(radius),
          ),
        );

    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(FurFeelTokens.space4),
      children: [
        shimmer(block(width: 220, height: 26, radius: 8)), // greeting
        const SizedBox(height: FurFeelTokens.space3),
        shimmer(
          // Status-hero-shaped card: avatar + name rows, pill, vitals row.
          Container(
            padding: const EdgeInsets.all(FurFeelTokens.space5),
            decoration: BoxDecoration(
              color: FurFeelTokens.surface,
              borderRadius: BorderRadius.circular(FurFeelTokens.radiusLg),
              border: Border.all(color: FurFeelTokens.hairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: FurFeelTokens.surfaceAlt,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: FurFeelTokens.space4),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        block(width: 120, height: 18),
                        const SizedBox(height: FurFeelTokens.space2),
                        block(width: 80, height: 12),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: FurFeelTokens.space4),
                block(width: 110, height: 32, radius: FurFeelTokens.radiusPill),
                const SizedBox(height: FurFeelTokens.space5),
                Row(
                  children: [
                    for (var i = 0; i < 3; i++) ...[
                      if (i > 0) const SizedBox(width: FurFeelTokens.space5),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          block(width: 64, height: 26),
                          const SizedBox(height: FurFeelTokens.space1),
                          block(width: 48, height: 10),
                        ],
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: FurFeelTokens.space3),
        shimmer(block(height: 52, radius: FurFeelTokens.radiusMd)), // today strip
      ],
    );
  }
}
