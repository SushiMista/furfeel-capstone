import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/furfeel_tokens.dart';
import 'micro_sparkline.dart';
import 'stress_pill.dart';

/// One vital, one card (docs/21 Redesign Plan §4, Phase 2).
///
/// The board this pattern comes from also featured a single blended "94%
/// health score" ring. That is deliberately not built here, and this widget is
/// shaped to make it awkward to build: it takes exactly one metric and has
/// nowhere to put a second. A one-number verdict on an animal's wellbeing is a
/// diagnostic claim in all but name, which is the line ADR-002 draws — see
/// ADR-021 for the full reasoning.
///
/// Purely presentational: callers own the fetching. That keeps it usable from
/// Home, the vital detail page, and widget tests without a repository.
class VitalStatCard extends StatelessWidget {
  const VitalStatCard({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    this.unit,
    this.descriptor,
    this.level,
    this.series = const <double?>[],
    this.onTap,
    this.timeframe,
    this.descriptorColor,
    this.seriesLabels,
  });

  /// e.g. "Stress level", "Heart rate".
  final String label;

  final IconData icon;

  /// Pre-formatted so the caller owns rounding — this widget will not decide
  /// how many decimals a heart rate deserves.
  final String value;

  /// e.g. "bpm", "pts". Sits baseline-aligned beside [value].
  final String? unit;

  /// One line of plain language: "Mostly calm", "Resting". The point of the
  /// card — a number the owner cannot interpret is not decision support.
  final String? descriptor;

  /// Tints the icon and the sparkline. Null renders both in brand blue, for
  /// vitals that carry no stress reading of their own.
  final StressLevel? level;

  /// Recent readings, oldest first. Typically 7. A `null` entry is an
  /// unreported day (track only).
  final List<double?> series;

  final VoidCallback? onTap;

  /// Muted scope affordance on the right of the header, e.g. "Today", "7 days"
  /// (the health-dashboard pattern). Pairs with the chevron when [onTap] is set.
  final String? timeframe;

  /// Renders [descriptor] as a coloured status tag (dot + soft chip) instead of
  /// muted text, so the read lands at a glance. Null keeps the plain muted text.
  /// It's a colour *on top of* the word — status never rides on colour alone.
  final Color? descriptorColor;

  /// Per-column captions under the sparkline, e.g. day initials `M T W T F S S`.
  final List<String>? seriesLabels;

  @override
  Widget build(BuildContext context) {
    final p = context.ff;
    final accent = level == null ? p.brand : stressLevelColor(context, level!);

    final card = Container(
      padding: const EdgeInsets.all(FurFeelTokens.space4),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(FurFeelTokens.radiusLg),
        border: Border.all(color: p.hairline),
        boxShadow: FurFeelTokens.shadowCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: accent),
              const SizedBox(width: FurFeelTokens.space2),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: FurFeelTokens.typeH3Size,
                    fontWeight: FurFeelTokens.typeH3Weight,
                    color: p.ink,
                  ),
                ),
              ),
              if (timeframe != null)
                Text(
                  timeframe!,
                  style: TextStyle(
                    fontSize: FurFeelTokens.typeCaptionSize,
                    color: p.inkMuted,
                  ),
                ),
              if (onTap != null)
                Icon(Icons.chevron_right, size: 18, color: p.inkMuted),
            ],
          ),
          const SizedBox(width: double.infinity, height: FurFeelTokens.space3),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          value,
                          style: TextStyle(
                            fontSize: FurFeelTokens.typeVitalNumberSize,
                            fontWeight: FurFeelTokens.typeVitalNumberWeight,
                            color: p.ink,
                            // Vitals update in place; without tabular figures
                            // the number jitters horizontally as digits change.
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        if (unit != null) ...[
                          const SizedBox(width: FurFeelTokens.space1),
                          Text(
                            unit!,
                            style: TextStyle(
                              fontSize: FurFeelTokens.typeCaptionSize,
                              color: p.inkMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (descriptor != null)
                      descriptorColor == null
                          ? Text(
                              descriptor!,
                              style: TextStyle(
                                fontSize: FurFeelTokens.typeCaptionSize,
                                color: p.inkMuted,
                              ),
                            )
                          : Container(
                              margin: const EdgeInsets.only(
                                  top: FurFeelTokens.space1),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: FurFeelTokens.space2, vertical: 2),
                              decoration: BoxDecoration(
                                color: descriptorColor!.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(
                                    FurFeelTokens.radiusPill),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: descriptorColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: FurFeelTokens.space1),
                                  Text(
                                    descriptor!,
                                    style: TextStyle(
                                      fontSize: FurFeelTokens.typeCaptionSize,
                                      fontWeight: FontWeight.w700,
                                      color: descriptorColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                  ],
                ),
              ),
              // MicroSparkline self-omits below two readings — a trend drawn
              // from one point is not a trend.
              MicroSparkline(
                series: series,
                labels: seriesLabels,
                color:
                    level == null ? p.brand : stressLevelChartFill(context, level!),
                trackColor:
                    level == null ? p.brandSoft : stressLevelSoftBg(context, level!),
              ),
            ],
          ),
        ],
      ),
    );

    return Semantics(
      container: true,
      button: onTap != null,
      // Must be re-declared here. `excludeSemantics` drops the InkWell's own
      // tap action along with its labels, so without this the card would
      // announce as a button and then do nothing when activated.
      onTap: onTap,
      label: [
        label,
        value,
        if (unit != null) unit,
        if (descriptor != null) descriptor,
      ].join(', '),
      // The visual tree carries the same strings; without this the reader
      // announces the label twice.
      excludeSemantics: true,
      child: onTap == null
          ? card
          : InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(FurFeelTokens.radiusLg),
              child: card,
            ),
    );
  }
}

