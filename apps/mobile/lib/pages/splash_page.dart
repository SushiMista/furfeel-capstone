import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/furfeel_tokens.dart';

/// Brand splash: shown on cold start while the app decides where to route,
/// and again while a signed-in user's settings load — a soft paw beat instead
/// of a spinner. Static under reduced motion.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;
    Widget paw = Icon(Icons.pets, size: 64, color: FurFeelTokens.brand);
    if (!reduce) {
      paw = paw
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scale(
            begin: const Offset(1, 1),
            end: const Offset(1.12, 1.12),
            duration: 700.ms,
            curve: Curves.easeInOut,
          )
          .fade(begin: 0.85, end: 1);
    }
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            paw,
            const SizedBox(height: FurFeelTokens.space4),
            Text(
              'FurFeel',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: FurFeelTokens.brandInk,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: FurFeelTokens.space2),
            Text(
              'Know how your dog is feeling',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: FurFeelTokens.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}
