import 'package:flutter/material.dart';

import '../theme/furfeel_tokens.dart';

/// Big friendly vital number with a small unit label (docs/19: "Numbers are
/// the hero on status screens").
class VitalNumber extends StatelessWidget {
  const VitalNumber({
    super.key,
    required this.label,
    required this.value,
    this.unit = '',
  });

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Value updates fade through instead of flickering (docs/19 §5a);
        // AnimatedSwitcher is instant under reduced motion (Duration.zero).
        AnimatedSwitcher(
          duration: MediaQuery.of(context).disableAnimations
              ? Duration.zero
              : FurFeelTokens.motionSlow,
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeOut,
          child: Text.rich(
          key: ValueKey(value),
          TextSpan(
            text: value,
            style: TextStyle(
              fontSize: FurFeelTokens.typeVitalNumberSize,
              fontWeight: FurFeelTokens.typeVitalNumberWeight,
              color: FurFeelTokens.ink,
              height: 1.2,
            ),
            children: [
              if (unit.isNotEmpty)
                TextSpan(
                  text: ' $unit',
                  style: TextStyle(
                    fontSize: FurFeelTokens.typeCaptionSize,
                    fontWeight: FontWeight.w400,
                    color: FurFeelTokens.inkMuted,
                  ),
                ),
            ],
          ),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: FurFeelTokens.typeCaptionSize,
            color: FurFeelTokens.inkMuted,
          ),
        ),
      ],
    );
  }
}
