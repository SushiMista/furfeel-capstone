import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/furfeel_tokens.dart';

/// Vitals trend chart (docs/19 §6: fl_chart LineChart with the shared palette).
/// Two series on one bpm axis — heart rate (owner coral) and respiratory rate
/// (accent teal) — muted grid, rounded caps, no chartjunk.
class VitalsChart extends StatelessWidget {
  const VitalsChart({super.key, required this.readings});

  /// Oldest-first readings (callers reverse the newest-first repository order).
  final List<TelemetryReading> readings;

  @override
  Widget build(BuildContext context) {
    final hrSpots = <FlSpot>[];
    final rrSpots = <FlSpot>[];
    for (final (i, r) in readings.indexed) {
      if (r.heartRateBpm != null) hrSpots.add(FlSpot(i.toDouble(), r.heartRateBpm!.toDouble()));
      if (r.respiratoryRateBpm != null) {
        rrSpots.add(FlSpot(i.toDouble(), r.respiratoryRateBpm!.toDouble()));
      }
    }
    if (hrSpots.isEmpty && rrSpots.isEmpty) return const SizedBox.shrink();

    LineChartBarData series(List<FlSpot> spots, Color color) => LineChartBarData(
          spots: spots,
          color: color,
          barWidth: 2.5,
          isCurved: true,
          preventCurveOverShooting: true,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 180,
          child: LineChart(
            LineChartData(
              lineBarsData: [
                series(hrSpots, FurFeelTokens.statusHighOwner),
                series(rrSpots, FurFeelTokens.accent),
              ],
              gridData: FlGridData(
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) =>
                    FlLine(color: FurFeelTokens.hairline, strokeWidth: 1),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                bottomTitles: const AxisTitles(),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 34,
                    getTitlesWidget: (value, meta) => Text(
                      meta.formattedValue,
                      style: TextStyle(
                        fontSize: FurFeelTokens.typeCaptionSize,
                        color: FurFeelTokens.inkMuted,
                      ),
                    ),
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineTouchData: const LineTouchData(enabled: false),
            ),
            duration: FurFeelTokens.motionSlow,
          ),
        ),
        SizedBox(height: FurFeelTokens.space2),
        Wrap(
          spacing: FurFeelTokens.space4,
          children: [
            _LegendItem(color: FurFeelTokens.statusHighOwner, label: 'Heart rate (bpm)'),
            _LegendItem(color: FurFeelTokens.accent, label: 'Breathing (bpm)'),
          ],
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: FurFeelTokens.space1),
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
