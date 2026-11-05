import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../insights/month_summary.dart';
import '../models/models.dart';
import '../theme/furfeel_tokens.dart';
import '../util/motion.dart';
import 'stress_pill.dart';

/// A month of a dog's days. Colour marks only days with readings, so a harness
/// left off never looks like a good day. Each day also speaks its level, and a
/// dot marks alerts, so nothing rests on colour alone (docs/19 §9).
class StressCalendar extends StatelessWidget {
  const StressCalendar({
    super.key,
    required this.month,
    required this.levels,
    required this.alertDays,
    required this.now,
    required this.onDayTap,
    this.scale = 1,
    this.loading = false,
  });

  final DateTime month;
  final Map<int, StressLevel?> levels; // day of month -> level
  final Set<int> alertDays;
  final DateTime now;
  final ValueChanged<DateTime> onDayTap;
  final double scale;

  /// Shows the month's shape as a shimmer while its days load.
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    // DateTime.weekday is Mon=1..Sun=7; the grid starts on Sunday.
    final lead = DateTime(month.year, month.month).weekday % 7;
    final diameter = 37 * scale;
    final cells = <Widget>[
      for (var i = 0; i < lead; i++) const SizedBox.shrink(),
      for (var day = 1; day <= daysInMonth; day++)
        loading
            ? Center(
                child: Container(
                  width: diameter,
                  height: diameter,
                  decoration: BoxDecoration(
                    color: context.ff.surfaceAlt,
                    shape: BoxShape.circle,
                  ),
                ),
              )
            : _DayCell(
                date: DateTime(month.year, month.month, day),
                level: levels[day],
                hasAlert: alertDays.contains(day),
                now: now,
                diameter: diameter,
                scale: scale,
                onTap: onDayTap,
              ),
    ];
    while (cells.length % 7 != 0) {
      cells.add(const SizedBox.shrink());
    }

    final grid = Column(
      children: [
        for (var i = 0; i < cells.length; i += 7)
          Row(
            children: [
              for (final cell in cells.sublist(i, i + 7))
                Expanded(
                  child: SizedBox(height: diameter + 5 * scale, child: cell),
                ),
            ],
          ),
      ],
    );

    return Column(
      children: [
        Row(
          children: [
            for (final letter in 'SMTWTFS'.split(''))
              Expanded(
                child: ExcludeSemantics(
                  child: Text(
                    letter,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 11 * scale,
                          letterSpacing: 0,
                          color: context.ff.inkMuted,
                        ),
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: 6 * scale),
        if (loading && !context.reduceMotion)
          grid
              .animate(onPlay: (c) => c.repeat())
              .shimmer(duration: 1200.ms, color: context.ff.surface)
        else
          grid,
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.level,
    required this.hasAlert,
    required this.now,
    required this.diameter,
    required this.scale,
    required this.onTap,
  });

  final DateTime date;
  final StressLevel? level;
  final bool hasAlert;
  final DateTime now;
  final double diameter;
  final double scale;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final isFuture = date.isAfter(now);
    final isToday = DateUtils.isSameDay(date, now);
    final level = this.level;
    final color = level != null
        ? stressLevelColor(context, level)
        : context.ff.inkMuted.withValues(alpha: isFuture ? 0.35 : 0.72);

    return Semantics(
      button: !isFuture,
      label: '${monthName(date)} ${date.day}, '
          '${isFuture ? 'upcoming' : dayWord(level)}'
          '${hasAlert ? ', has an alert' : ''}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: isFuture ? null : () => onTap(date),
        child: Center(
          child: Container(
            width: diameter,
            height: diameter,
            decoration: BoxDecoration(
              color: level == null ? null : stressLevelSoftBg(context, level),
              shape: BoxShape.circle,
              border: isToday
                  ? Border.all(color: context.ff.brand, width: 2)
                  : null,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  '${date.day}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: color,
                        fontSize: 13 * scale,
                        letterSpacing: 0,
                        fontWeight:
                            level == null ? FontWeight.w400 : FontWeight.w600,
                      ),
                ),
                if (hasAlert)
                  Positioned(
                    bottom: 4 * scale,
                    child: Container(
                      width: 4 * scale,
                      height: 4 * scale,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
