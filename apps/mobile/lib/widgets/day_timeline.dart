import 'package:flutter/material.dart';

import '../data/furfeel_repository.dart';
import '../insights/owner_moments.dart';
import '../models/models.dart';
import '../theme/furfeel_tokens.dart';
import '../util/motion.dart';
import 'stress_pill.dart';

/// Formats an hour-of-day (0-23) the way an owner reads a clock.
String hourLabel(int hour) {
  if (hour == 0) return '12am';
  if (hour == 12) return 'noon';
  return hour < 12 ? '${hour}am' : '${hour - 12}pm';
}

/// Today's stress as a banded strip (docs/19 §6): one segment per hour,
/// dominant level wins, gaps stay neutral. Self-loading so any screen can drop
/// it in. Word legend keeps meaning off color alone (docs/19 §9).
///
/// Tracker-style: discrete tappable blocks rather than one continuous bar, and
/// tapping any block names that hour in words above the strip ("2pm · Calm").
/// A colour band alone tells you the day had *some* shape but never which hour
/// was which — the readout is what makes it answer a question.
class DayTimeline extends StatefulWidget {
  const DayTimeline({super.key, required this.repository, required this.dog});

  final FurFeelRepository repository;
  final Dog dog;

  @override
  State<DayTimeline> createState() => _DayTimelineState();
}

class _DayTimelineState extends State<DayTimeline> {
  List<StressLevel?>? _hours;

  /// Hour the owner tapped. Null = show the most recent hour that has data,
  /// so the readout always says something without needing a tap first.
  int? _selectedHour;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(DayTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dog.id != widget.dog.id) {
      setState(() {
        _hours = null;
        _selectedHour = null;
      });
      _load();
    }
  }

  /// The hour the readout describes: the tapped one, else the latest with data.
  int? _readoutHour(List<StressLevel?> hours) {
    if (_selectedHour != null) return _selectedHour;
    for (var h = hours.length - 1; h >= 0; h--) {
      if (hours[h] != null) return h;
    }
    return null;
  }

  Future<void> _load() async {
    final now = DateTime.now();
    final dayStart = DateTime(now.year, now.month, now.day);
    try {
      final classifications = await widget.repository
          .fetchClassificationsBetween(widget.dog.id, dayStart, now);
      if (mounted) {
        setState(
            () => _hours = hourlyDominantLevels(classifications, dayStart));
      }
    } catch (_) {
      // Leave the strip hidden; the rest of the screen carries the day.
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hours = _hours;
    if (hours == null || hours.every((h) => h == null)) {
      return const SizedBox.shrink();
    }
    final nowHour = DateTime.now().hour;
    final readoutHour = _readoutHour(hours);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(FurFeelTokens.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('TODAY, HOUR BY HOUR', style: textTheme.labelSmall),
            const SizedBox(height: FurFeelTokens.space2),
            // Readout: names the hour the colour band can only imply.
            _HourReadout(hour: readoutHour, hours: hours),
            const SizedBox(height: FurFeelTokens.space3),
            SizedBox(
              height: 30,
              child: Row(
                children: [
                  for (final (hour, level) in hours.indexed)
                    Expanded(
                      child: _HourBlock(
                        hour: hour,
                        level: level,
                        isFuture: hour > nowHour,
                        isSelected: hour == readoutHour,
                        onTap: () => setState(
                          // Tapping the selected block clears back to "latest".
                          () => _selectedHour = _selectedHour == hour ? null : hour,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: FurFeelTokens.space1),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(hourLabel(0), style: textTheme.bodySmall),
                Text(hourLabel(12), style: textTheme.bodySmall),
                Text('now', style: textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: FurFeelTokens.space2),
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
                          color: stressLevelColor(context, level),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: FurFeelTokens.space1),
                      Text(
                        level.name[0].toUpperCase() + level.name.substring(1),
                        style: TextStyle(
                          fontSize: FurFeelTokens.typeCaptionSize,
                          color: context.ff.inkMuted,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One hour in the strip. Discrete rounded block with a gap rather than a slice
/// of a continuous bar, so each hour reads as its own unit you can aim at.
class _HourBlock extends StatelessWidget {
  const _HourBlock({
    required this.hour,
    required this.level,
    required this.isFuture,
    required this.isSelected,
    required this.onTap,
  });

  final int hour;
  final StressLevel? level;
  final bool isFuture;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fill = isFuture
        // Hasn't happened yet: outline only, so the day's full span still
        // reads without implying we measured something.
        ? Colors.transparent
        : level == null
            ? context.ff.surfaceAlt
            : stressLevelColor(context, level!);

    return Semantics(
      button: true,
      selected: isSelected,
      label: '${hourLabel(hour)}, ${_levelWord(level, isFuture: isFuture)}',
      child: GestureDetector(
        onTap: isFuture ? null : onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          // Gap between blocks; padding (not margin) keeps the tap target
          // full-width so thin hourly blocks stay reachable.
          padding: const EdgeInsets.symmetric(horizontal: 0.75),
          child: AnimatedContainer(
            duration: context.reduceMotion ? Duration.zero : FurFeelTokens.motionFast,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(3),
              border: isFuture
                  ? Border.all(color: context.ff.hairline)
                  // Selection is a ring, never a colour change -- the block's
                  // colour already means the stress level (docs/19 §9).
                  : isSelected
                      ? Border.all(color: context.ff.ink, width: 2)
                      : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// Plain-language line naming the hour under inspection.
class _HourReadout extends StatelessWidget {
  const _HourReadout({required this.hour, required this.hours});

  final int? hour;
  final List<StressLevel?> hours;

  @override
  Widget build(BuildContext context) {
    if (hour == null) {
      return Text(
        'No readings yet today',
        style: TextStyle(
          fontSize: FurFeelTokens.typeBodyMobileSize,
          color: context.ff.inkMuted,
        ),
      );
    }
    final level = hours[hour!];
    return Row(
      children: [
        Text(
          hourLabel(hour!),
          style: TextStyle(
            fontSize: FurFeelTokens.typeBodyMobileSize,
            fontWeight: FontWeight.w700,
            color: context.ff.ink,
          ),
        ),
        Text(
          '  ·  ${_levelWord(level, isFuture: false)}',
          style: TextStyle(
            fontSize: FurFeelTokens.typeBodyMobileSize,
            color: level == null ? context.ff.inkMuted : stressLevelColor(context, level),
            fontWeight: level == null ? FontWeight.w400 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

String _levelWord(StressLevel? level, {required bool isFuture}) {
  if (isFuture) return 'later today';
  if (level == null) return 'no readings';
  return level.name[0].toUpperCase() + level.name.substring(1);
}
