import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/furfeel_tokens.dart';

Color stressLevelColor(BuildContext context, StressLevel level) => switch (level) {
      StressLevel.calm => context.ff.statusCalmFg,
      StressLevel.mild => context.ff.statusMildFg,
      StressLevel.moderate => context.ff.statusModerateFg,
      // Owner app softens `high` to coral for a less alarming feel (docs/19
      // status ramp note); the dashboard keeps the full clinical red.
      StressLevel.high => context.ff.statusHighOwner,
    };

Color stressLevelSoftBg(BuildContext context, StressLevel level) => switch (level) {
      StressLevel.calm => context.ff.statusCalmBg,
      StressLevel.mild => context.ff.statusMildBg,
      StressLevel.moderate => context.ff.statusModerateBg,
      StressLevel.high => context.ff.statusHighBg,
    };

/// Status pill (docs/19): soft-bg fill + colored text + a small dot, always
/// paired with the word so meaning never rides on color alone. Stress-level
/// changes cross-fade rather than snapping, with a single soft scale pulse
/// only when the *level* changes (docs/19 §5a) — never on every reading.
class StressPill extends StatefulWidget {
  const StressPill({super.key, required this.level, this.large = false});

  final StressLevel level;
  final bool large;

  @override
  State<StressPill> createState() => _StressPillState();
}

class _StressPillState extends State<StressPill> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: FurFeelTokens.motionSlow,
  );

  @override
  void didUpdateWidget(StressPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.level != widget.level &&
        !MediaQuery.of(context).disableAnimations) {
      _pulse.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final level = widget.level;
    final large = widget.large;
    final fg = stressLevelColor(context, level);
    final bg = stressLevelSoftBg(context, level);
    return ScaleTransition(
      // 1 → 1.06 → 1: one gentle heartbeat, then still.
      scale: TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 1, end: 1.06), weight: 1),
        TweenSequenceItem(tween: Tween(begin: 1.06, end: 1), weight: 1),
      ]).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)),
      child: AnimatedContainer(
      duration: FurFeelTokens.motionSlow,
      curve: Curves.easeOut,
      padding: EdgeInsets.symmetric(
        horizontal: large ? FurFeelTokens.space4 : FurFeelTokens.space3,
        vertical: large ? FurFeelTokens.space2 : FurFeelTokens.space1,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(FurFeelTokens.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: large ? 10 : 8,
            height: large ? 10 : 8,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          SizedBox(width: large ? FurFeelTokens.space2 : FurFeelTokens.space1),
          Text(
            // Capitalized word (Calm / Mild / Moderate / High) for accessibility.
            level.name[0].toUpperCase() + level.name.substring(1),
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w700,
              fontSize: large ? FurFeelTokens.typeH2Size : FurFeelTokens.typeLabelSize,
            ),
          ),
        ],
      ),
      ),
    );
  }
}
