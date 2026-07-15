import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/activity_state.dart';
import '../theme/furfeel_tokens.dart';
import '../util/motion.dart';

/// Paw icon whose motion mirrors the dog's current activity (docs/19 §5a:
/// motion communicates state, word carries meaning):
/// - resting: slow breathing pulse
/// - moving: gentle walking bob
/// - very active: the same bob, faster
/// - sitting / standing / no signal: still
/// Static under reduced motion; the label next to it always tells the story.
class ActivityIndicator extends StatelessWidget {
  const ActivityIndicator({super.key, required this.state, this.size = 28});

  final ActivityState state;
  final double size;

  @override
  Widget build(BuildContext context) {
    final muted = state == ActivityState.noSignal;
    final icon = Icon(
      muted ? Icons.sensors_off_outlined : Icons.pets,
      size: size,
      color: muted ? FurFeelTokens.inkMuted : FurFeelTokens.brand,
    );
    if (context.reduceMotion) return icon;

    return switch (state) {
      ActivityState.resting => icon
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scale(
            begin: const Offset(1, 1),
            end: const Offset(1.08, 1.08),
            duration: 1400.ms,
            curve: Curves.easeInOut,
          )
          .fade(begin: 0.75, end: 1),
      ActivityState.moving => icon
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .moveY(begin: -1.5, end: 1.5, duration: 420.ms, curve: Curves.easeInOut),
      ActivityState.veryActive => icon
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .moveY(begin: -2.5, end: 2.5, duration: 220.ms, curve: Curves.easeInOut),
      _ => icon,
    };
  }
}
