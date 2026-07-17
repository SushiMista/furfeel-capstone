/// Owner-delight logic (setup checklist, calm streaks, today timeline).
/// Pure functions — no I/O — so the warm parts of the app stay unit-tested.
/// All copy stays observational: streaks celebrate what the data showed,
/// never why.
library;

import '../models/models.dart';

/// One step of the guided setup checklist shown on Home until complete.
enum SetupStep {
  pairHarness('Pair the harness', 'Readings start once it\'s on and connected'),
  linkClinic('Choose a clinic (optional)',
      'Their care team can keep an eye on things too'),
  firstReading('First reading', 'Automatic — give the harness a minute');

  const SetupStep(this.title, this.subtitle);
  final String title;
  final String subtitle;
}

/// Which setup steps are done for this dog. The checklist card hides itself
/// once the essentials (harness + a reading) are in — a linked clinic is
/// optional and never blocks "done".
Map<SetupStep, bool> setupProgress({
  required bool hasDevice,
  required bool hasClinic,
  required bool hasReading,
}) =>
    {
      SetupStep.pairHarness: hasDevice,
      SetupStep.linkClinic: hasClinic,
      SetupStep.firstReading: hasReading,
    };

bool setupComplete(Map<SetupStep, bool> progress) =>
    (progress[SetupStep.pairHarness] ?? false) &&
    (progress[SetupStep.firstReading] ?? false);

/// Consecutive days (ending today, or yesterday when today has no data yet)
/// where at least [threshold] of classifications were calm. 0 = no streak.
/// Threshold is provisional and product-tunable, not clinical.
int calmStreak(
  List<DailyStressSummary> daily,
  DateTime now, {
  double threshold = 0.7,
}) {
  final byDay = <DateTime, DailyStressSummary>{
    for (final d in daily) DateTime(d.day.year, d.day.month, d.day.day): d,
  };
  var day = DateTime(now.year, now.month, now.day);
  // Today often has little data yet — an empty today doesn't break the streak.
  if ((byDay[day]?.total ?? 0) == 0) day = day.subtract(const Duration(days: 1));

  var streak = 0;
  while (true) {
    final summary = byDay[day];
    final share = summary?.calmShare;
    if (summary == null || summary.total == 0 || share == null || share < threshold) {
      break;
    }
    streak += 1;
    day = day.subtract(const Duration(days: 1));
  }
  return streak;
}

/// Dominant stress level for each hour of [day] (local), null = no data that
/// hour. Feeds the today-timeline strip (docs/19 §6 "stress timeline as a
/// banded strip").
List<StressLevel?> hourlyDominantLevels(
  List<StressClassification> classifications,
  DateTime day,
) {
  final counts = List.generate(24, (_) => <StressLevel, int>{});
  for (final c in classifications) {
    final t = c.createdAt;
    if (t.year != day.year || t.month != day.month || t.day != day.day) continue;
    counts[t.hour].update(c.stressLevel, (n) => n + 1, ifAbsent: () => 1);
  }
  return [
    for (final hour in counts)
      hour.isEmpty
          ? null
          // Ties break toward the more elevated level — the honest read.
          : (hour.entries.toList()
                ..sort((a, b) {
                  final byCount = a.value.compareTo(b.value);
                  return byCount != 0 ? byCount : a.key.index.compareTo(b.key.index);
                }))
              .last
              .key,
  ];
}
