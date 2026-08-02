import 'package:flutter/material.dart';

import '../theme/furfeel_tokens.dart';

/// The one section heading used across the app (docs/22 v7): a bold, sentence-
/// case title with an optional muted hint on the right. Replaces the old
/// ALL-CAPS `labelSmall` section labels, which read clinical against the
/// immersive redesign's two-weight (light / bold) type.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.hint, this.onHintTap});

  final String title;

  /// Muted affordance on the right, e.g. "See all", "7 days".
  final String? hint;
  final VoidCallback? onHintTap;

  @override
  Widget build(BuildContext context) {
    final p = context.ff;
    final titleWidget = Text(
      title,
      style: TextStyle(
        fontSize: FurFeelTokens.typeH2Size,
        fontWeight: FontWeight.w800,
        color: p.ink,
      ),
    );
    // No hint → a plain Text that works in any width context and still wraps.
    if (hint == null) return titleWidget;

    // With a hint, the title flexes so title + hint never overflow (e.g. at
    // large text scale). Used only in bounded contexts (lists, the home).
    final hintWidget = Text(
      hint!,
      style: TextStyle(
        fontSize: FurFeelTokens.typeCaptionSize,
        color: onHintTap == null ? p.inkMuted : p.brand,
        fontWeight: onHintTap == null ? FontWeight.w300 : FontWeight.w700,
      ),
    );
    return Row(
      children: [
        Expanded(child: titleWidget),
        const SizedBox(width: FurFeelTokens.space2),
        onHintTap == null
            ? hintWidget
            : GestureDetector(onTap: onHintTap, child: hintWidget),
      ],
    );
  }
}
