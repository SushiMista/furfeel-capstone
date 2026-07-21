import 'package:flutter/material.dart';

import '../theme/furfeel_tokens.dart';

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

/// At-a-glance overview strip (mirrors the dashboard's clinic KPI row in
/// apps/dashboard/src/pages/overview/Overview.tsx) — dogs monitored, calm
/// today, needs attention, alerts, devices offline, built entirely from data
/// the caller already has in memory. No queries here.
class OverviewStatsCard extends StatelessWidget {
  const OverviewStatsCard({super.key, required this.stats});

  final List<OverviewStat> stats;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(FurFeelTokens.space4),
        child: Wrap(
          spacing: FurFeelTokens.space4,
          runSpacing: FurFeelTokens.space3,
          children: [for (final s in stats) _StatTile(stat: s)],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.stat});

  final OverviewStat stat;

  @override
  Widget build(BuildContext context) {
    final color = stat.attention ? context.ff.statusHighOwner : context.ff.brand;
    final bg = stat.attention ? context.ff.statusHighBg : context.ff.brandSoft;
    return SizedBox(
      width: 92,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(FurFeelTokens.space2),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(FurFeelTokens.radiusSm),
            ),
            child: Icon(stat.icon, size: 16, color: color),
          ),
          const SizedBox(height: FurFeelTokens.space2),
          Text(
            stat.value,
            style: TextStyle(
              fontSize: FurFeelTokens.typeH3Size,
              fontWeight: FontWeight.w700,
              color: context.ff.ink,
            ),
          ),
          Text(
            stat.label,
            style: TextStyle(
              fontSize: FurFeelTokens.typeCaptionSize,
              fontWeight: FontWeight.w600,
              color: context.ff.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}
