import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

import '../theme/furfeel_tokens.dart';
import '../theme/shadcn_bridge.dart';

/// One at-a-glance stat (docs/04 Home): word + icon, never color alone.
class OverviewStat {
  const OverviewStat({
    required this.label,
    required this.value,
    required this.icon,
    this.attention = false,
  });

  final String label;
  final String value;
  final IconData icon;

  /// True when this stat calls for the owner's attention (needs-attention
  /// count > 0, offline devices, etc.) — swaps the tint from brand to warn.
  final bool attention;
}

/// Sleek single-line pack status header bar (docs/04 Home).
/// Replaces bulky multi-tile cards with a clean, minimal status strip:
/// e.g. "🐾 2 Dogs Monitored • All systems normal" or "⚠️ 1 Needs attention".
class OverviewStatsCard extends StatelessWidget {
  const OverviewStatsCard({
    super.key,
    required this.stats,
    this.sortValue = 'name',
    this.onSortChanged,
  });

  final List<OverviewStat> stats;
  final String sortValue;
  final ValueChanged<String>? onSortChanged;

  @override
  Widget build(BuildContext context) {
    // Extract monitored dogs count
    final dogsStat = stats.firstWhere(
      (s) => s.label.toLowerCase().contains('dogs monitored') || s.label.toLowerCase().contains('dog'),
      orElse: () => stats.isNotEmpty
          ? stats.first
          : const OverviewStat(label: 'Dogs monitored', value: '1', icon: Icons.pets),
    );

    final dogCount = int.tryParse(dogsStat.value) ?? 1;
    final dogLabel = dogCount == 1 ? 'Dog monitored' : 'Dogs monitored';

    final sortLabel = switch (sortValue) {
      'stress' => 'Stress Level',
      'alerts' => 'Open Alerts',
      _ => 'Name',
    };

    return shadcn.Theme(
      data: furFeelShadcnTheme(context),
      child: shadcn.Card(
        filled: true,
        fillColor: context.ff.surface,
        borderColor: context.ff.hairline,
        borderRadius: BorderRadius.circular(FurFeelTokens.radiusLg),
        boxShadow: FurFeelTokens.shadowCard,
        padding: const EdgeInsets.symmetric(
          horizontal: FurFeelTokens.space4,
          vertical: FurFeelTokens.space3,
        ),
        child: Row(
          children: [
            // Paw Icon
            Container(
              padding: const EdgeInsets.all(FurFeelTokens.space2),
              decoration: BoxDecoration(
                color: context.ff.brandSoft,
                borderRadius: BorderRadius.circular(FurFeelTokens.radiusSm),
              ),
              child: Icon(
                Icons.pets,
                size: 16,
                color: context.ff.brand,
              ),
            ),
            const SizedBox(width: FurFeelTokens.space3),
            // Total Dogs Monitored Count & Label
            Expanded(
              child: Row(
                children: [
                  shadcn.NumberTicker(
                    number: dogCount,
                    formatter: (v) => '${v.toInt()} ',
                    duration: FurFeelTokens.motionSlow,
                    style: TextStyle(
                      fontSize: FurFeelTokens.typeH3Size,
                      fontWeight: FontWeight.w800,
                      color: context.ff.ink,
                    ),
                  ),
                  Flexible(
                    child: Text(
                      dogLabel,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: FurFeelTokens.typeBodySize,
                        fontWeight: FontWeight.w600,
                        color: context.ff.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: FurFeelTokens.space2),
            // Sorting Dropdown
            if (onSortChanged != null)
              Theme(
                data: Theme.of(context).copyWith(
                  popupMenuTheme: PopupMenuThemeData(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(FurFeelTokens.radiusMd),
                    ),
                    color: context.ff.surface,
                  ),
                ),
                child: PopupMenuButton<String>(
                  initialValue: sortValue,
                  onSelected: onSortChanged,
                  offset: const Offset(0, 40),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: FurFeelTokens.space3,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: context.ff.surface,
                      borderRadius: BorderRadius.circular(FurFeelTokens.radiusPill),
                      border: Border.all(color: context.ff.hairline),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.sort, size: 14, color: context.ff.inkMuted),
                        const SizedBox(width: 4),
                        Text(
                          'Sort: $sortLabel',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: context.ff.inkMuted,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.keyboard_arrow_down, size: 14, color: context.ff.inkMuted),
                      ],
                    ),
                  ),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'name',
                      child: Text('Name (A-Z)', style: TextStyle(fontSize: 14)),
                    ),
                    const PopupMenuItem(
                      value: 'stress',
                      child: Text('Stress Level', style: TextStyle(fontSize: 14)),
                    ),
                    const PopupMenuItem(
                      value: 'alerts',
                      child: Text('Open Alerts', style: TextStyle(fontSize: 14)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
