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

/// Sleek single-line pack status header bar (docs/04 Home).
/// Replaces bulky multi-tile cards with a clean, minimal status strip:
/// e.g. "🐾 2 Dogs Monitored • All systems normal" or "⚠️ 1 Needs attention".
class OverviewStatsCard extends StatelessWidget {
  const OverviewStatsCard({super.key, required this.stats});

  final List<OverviewStat> stats;

  @override
  Widget build(BuildContext context) {
    // Extract monitored dogs count
    final dogsStat = stats.firstWhere(
      (s) => s.label.toLowerCase().contains('dogs monitored') || s.label.toLowerCase().contains('dog'),
      orElse: () => stats.isNotEmpty
          ? stats.first
          : const OverviewStat(label: 'Dogs monitored', value: '1', icon: Icons.pets),
    );

    final needsAttentionStat = stats.firstWhere(
      (s) => s.label.toLowerCase().contains('needs attention'),
      orElse: () => const OverviewStat(label: 'Needs attention', value: '0', icon: Icons.monitor_heart),
    );

    final alertsStat = stats.firstWhere(
      (s) => s.label.toLowerCase().contains('alert'),
      orElse: () => const OverviewStat(label: 'Alerts today', value: '0', icon: Icons.notifications_outlined),
    );

    final offlineStat = stats.firstWhere(
      (s) => s.label.toLowerCase().contains('offline'),
      orElse: () => const OverviewStat(label: 'Devices offline', value: '0', icon: Icons.wifi_off),
    );

    final dogCount = int.tryParse(dogsStat.value) ?? 1;
    final needsAttentionCount = int.tryParse(needsAttentionStat.value) ?? 0;
    final alertsCount = int.tryParse(alertsStat.value) ?? 0;
    final offlineCount = int.tryParse(offlineStat.value) ?? 0;

    final hasAttention = needsAttentionCount > 0 || alertsCount > 0;
    final hasOffline = offlineCount > 0;

    // Status pill config
    final String statusText;
    final IconData statusIcon;
    final Color statusFg;
    final Color statusBg;

    if (hasAttention) {
      final issueCount = needsAttentionCount > 0 ? needsAttentionCount : alertsCount;
      statusText = '$issueCount Needs attention';
      statusIcon = Icons.warning_amber_rounded;
      statusFg = context.ff.statusHighOwner;
      statusBg = context.ff.statusHighBg;
    } else if (hasOffline) {
      statusText = '$offlineCount Offline';
      statusIcon = Icons.wifi_off;
      statusFg = context.ff.warm;
      statusBg = context.ff.warmSoft;
    } else {
      statusText = 'All systems normal';
      statusIcon = Icons.check_circle_outline_rounded;
      statusFg = context.ff.statusCalmFg;
      statusBg = context.ff.statusCalmBg;
    }

    final dogLabel = dogCount == 1 ? 'Dog monitored' : 'Dogs monitored';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: FurFeelTokens.space4,
        vertical: FurFeelTokens.space3,
      ),
      decoration: BoxDecoration(
        color: context.ff.surface,
        borderRadius: BorderRadius.circular(FurFeelTokens.radiusLg),
        border: Border.all(color: context.ff.hairline),
        boxShadow: FurFeelTokens.shadowCard,
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
                Text(
                  '${dogsStat.value} ',
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
          // Status Badge
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: FurFeelTokens.space3,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(FurFeelTokens.radiusPill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon, size: 14, color: statusFg),
                const SizedBox(width: 4),
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: statusFg,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

