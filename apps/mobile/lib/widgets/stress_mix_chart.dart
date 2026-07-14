import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/furfeel_tokens.dart';

// Getter, not const: token colors resolve against the active theme.
Map<StressLevel, Color> get _levelColors => <StressLevel, Color>{
      StressLevel.calm: FurFeelTokens.statusCalmFg,
      StressLevel.mild: FurFeelTokens.statusMildFg,
      StressLevel.moderate: FurFeelTokens.statusModerateFg,
      StressLevel.high: FurFeelTokens.statusHighOwner,
    };

/// Daily stress mix as a 100%-stacked bar per day: composition, not volume,
/// is the owner's question ("how much of the day was calm?"). Status colors
/// carry the levels; a word legend keeps meaning off color alone (docs/19 §9).
class StressMixChart extends StatelessWidget {
  const StressMixChart({super.key, required this.daily});

  /// Oldest-first daily summaries (days with zero samples render empty).
  final List<DailyStressSummary> daily;

  @override
  Widget build(BuildContext context) {
    if (daily.isEmpty) return const SizedBox.shrink();

    final groups = <BarChartGroupData>[];
    for (final (i, d) in daily.indexed) {
      final total = d.total;
      if (total == 0) {
        groups.add(BarChartGroupData(x: i));
        continue;
      }
      // Cumulative 0..100 stack, calm at the base (the reassuring anchor).
      final shares = [
        (StressLevel.calm, d.calm / total * 100),
        (StressLevel.mild, d.mild / total * 100),
        (StressLevel.moderate, d.moderate / total * 100),
        (StressLevel.high, d.high / total * 100),
      ];
      final items = <BarChartRodStackItem>[];
      var from = 0.0;
      for (final (level, share) in shares) {
        if (share <= 0) continue;
        items.add(BarChartRodStackItem(
          from,
          from + share,
          _levelColors[level]!,
          // Hairline surface gap between segments so stacks read as parts.
          borderSide: BorderSide(color: FurFeelTokens.surface, width: 1),
        ));
        from += share;
      }
      groups.add(BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: 100,
            // Bars slim down as the window widens so a month still fits.
            width: daily.length > 16 ? 7 : 14,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            rodStackItems: items,
          ),
        ],
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 160,
          child: BarChart(
            BarChartData(
              maxY: 100,
              barGroups: groups,
              alignment: BarChartAlignment.spaceAround,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              barTouchData: BarTouchData(enabled: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: const AxisTitles(),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 26,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= daily.length) return const SizedBox.shrink();
                      // QA: label density adapts to the range — a 7-day window
                      // shows weekday + date ("Sun 6"), 14 days shows weekday
                      // initials, a month shows dates every few days.
                      const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                      const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                      final day = daily[i].day;
                      final String? label;
                      if (daily.length <= 8) {
                        label = '${names[day.weekday - 1]}\n${day.day}';
                      } else if (daily.length <= 16) {
                        label = i.isOdd ? null : letters[day.weekday - 1];
                      } else {
                        label = i % 5 == 0 ? '${day.month}/${day.day}' : null;
                      }
                      if (label == null) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            height: 1.1,
                            color: FurFeelTokens.inkMuted,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            duration: FurFeelTokens.motionSlow,
          ),
        ),
        const SizedBox(height: FurFeelTokens.space3),
        Wrap(
          spacing: FurFeelTokens.space4,
          runSpacing: FurFeelTokens.space1,
          children: [
            for (final level in StressLevel.values)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _levelColors[level],
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: FurFeelTokens.space1),
                  Text(
                    level.name[0].toUpperCase() + level.name.substring(1),
                    style: TextStyle(
                      fontSize: FurFeelTokens.typeCaptionSize,
                      color: FurFeelTokens.inkMuted,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
