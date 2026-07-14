import 'package:flutter/material.dart';

import '../theme/furfeel_tokens.dart';

/// ADDED (QA): the brand wordmark — paw glyph + "FurFeel" — used in the app
/// bar, splash, and welcome screens instead of emojis or the dog's name.
class FurFeelLogo extends StatelessWidget {
  const FurFeelLogo({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.pets, size: size, color: FurFeelTokens.brand),
        SizedBox(width: size * 0.4),
        Text(
          'FurFeel',
          style: TextStyle(
            fontSize: size,
            fontWeight: FontWeight.w800,
            color: FurFeelTokens.brandInk,
          ),
        ),
      ],
    );
  }
}
