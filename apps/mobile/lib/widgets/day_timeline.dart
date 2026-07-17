import 'package:flutter/material.dart';

import '../data/furfeel_repository.dart';
import '../insights/owner_moments.dart';
import '../models/models.dart';
import '../theme/furfeel_tokens.dart';
import 'stress_pill.dart';

/// Today's stress as a banded strip (docs/19 §6): one colored segment per
/// hour, dominant level wins, gaps stay neutral. Self-loading so any screen
/// can drop it in. Word legend keeps meaning off color alone (docs/19 §9).
class DayTimeline extends StatefulWidget {
  const DayTimeline({super.key, required this.repository, required this.dog});

  final FurFeelRepository repository;
  final Dog dog;

  @override
  State<DayTimeline> createState() => _DayTimelineState();
}

class _DayTimelineState extends State<DayTimeline> {
  List<StressLevel?>? _hours;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(DayTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dog.id != widget.dog.id) {
      setState(() => _hours = null);
      _load();
    }
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(FurFeelTokens.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('TODAY, HOUR BY HOUR', style: textTheme.labelSmall),
            const SizedBox(height: FurFeelTokens.space3),
            ClipRRect(
              borderRadius: BorderRadius.circular(FurFeelTokens.radiusPill),
              child: SizedBox(
                height: 14,
                child: Row(
                  children: [
                    for (final (hour, level) in hours.indexed)
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 0.5),
                          color: hour > nowHour
                              // The rest of the day hasn't happened yet.
                              ? Colors.transparent
                              : level == null
                                  ? FurFeelTokens.surfaceAlt
                                  : stressLevelColor(level),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: FurFeelTokens.space1),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('12am', style: textTheme.bodySmall),
                Text('noon', style: textTheme.bodySmall),
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
                          color: stressLevelColor(level),
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
        ),
      ),
    );
  }
}
