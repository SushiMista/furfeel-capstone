/// Owner-facing insight engine (docs/04 "actionable, simple visualizations").
///
/// Pure functions over the server-side summaries — no I/O, fully unit-tested.
/// Every insight is an *observation with a suggestion*, worded with "tends to"
/// / "worth a look": decision support, never causal claims, never diagnosis.
library;

import '../models/models.dart';

enum InsightTone { positive, neutral, attention }

enum InsightKind { weeklyTrend, dayPart, activity, alerts, coverage }

class Insight {
  const Insight({
    required this.kind,
    required this.tone,
    required this.title,
    required this.body,
  });

  final InsightKind kind;
  final InsightTone tone;
  final String title;
  final String body;
}

/// Pooled calm share over a set of days; null when there's no data at all.
double? calmShare(Iterable<DailyStressSummary> days) {
  var calm = 0;
  var total = 0;
  for (final d in days) {
    calm += d.calm;
    total += d.total;
  }
  return total == 0 ? null : calm / total;
}

/// This week's vs last week's calm share, relative to [now].
({double? current, double? previous}) weekOverWeekCalm(
  List<DailyStressSummary> daily,
  DateTime now,
) {
  final today = DateTime(now.year, now.month, now.day);
  final weekAgo = today.subtract(const Duration(days: 6));
  final prevStart = today.subtract(const Duration(days: 13));
  bool inRange(DateTime d, DateTime from, DateTime to) =>
      !d.isBefore(from) && !d.isAfter(to);
  return (
    current: calmShare(daily.where((d) => inRange(d.day, weekAgo, today))),
    previous: calmShare(
        daily.where((d) => inRange(d.day, prevStart, weekAgo.subtract(const Duration(days: 1))))),
  );
}

/// Named parts of the day used for the calmest/tensest pattern.
const dayParts = <({String name, int fromHour, int toHour})>[
  (name: 'overnight', fromHour: 0, toHour: 5),
  (name: 'in the morning', fromHour: 6, toHour: 11),
  (name: 'in the afternoon', fromHour: 12, toHour: 17),
  (name: 'in the evening', fromHour: 18, toHour: 23),
];

/// Minimum classifications a day-part needs before we trust its share.
const _minDayPartSamples = 30;

/// Calm share per day-part, skipping parts with too little data.
List<({String name, double share})> dayPartCalmShares(List<HourlyStressBucket> hourly) {
  final result = <({String name, double share})>[];
  for (final part in dayParts) {
    var calm = 0;
    var total = 0;
    for (final b in hourly) {
      if (b.hour >= part.fromHour && b.hour <= part.toHour) {
        calm += b.calm;
        total += b.total;
      }
    }
    if (total >= _minDayPartSamples) {
      result.add((name: part.name, share: calm / total));
    }
  }
  return result;
}

int _pct(double v) => (v * 100).round();

/// Builds the "what seems to help" cards, most useful first. Emits nothing it
/// can't back with enough data — an absent insight beats a made-up one.
List<Insight> buildInsights({
  required String dogName,
  required List<DailyStressSummary> daily,
  required List<HourlyStressBucket> hourly,
  required List<Alert> alerts,
  required DateTime now,
}) {
  final insights = <Insight>[];

  // 1. Week-over-week calm trend.
  final week = weekOverWeekCalm(daily, now);
  final current = week.current;
  final previous = week.previous;
  if (current != null && previous != null) {
    final delta = current - previous;
    if (delta >= 0.05) {
      insights.add(Insight(
        kind: InsightKind.weeklyTrend,
        tone: InsightTone.positive,
        title: 'More calm time this week',
        body: '$dogName was calm ${_pct(current)}% of the time, up from '
            '${_pct(previous)}% last week. Whatever changed, it agrees with '
            '$dogName — keep it going.',
      ));
    } else if (delta <= -0.05) {
      insights.add(Insight(
        kind: InsightKind.weeklyTrend,
        tone: InsightTone.attention,
        title: 'A little less calm time this week',
        body: 'Calm time slipped from ${_pct(previous)}% to ${_pct(current)}%. '
            'Worth a think about what changed — new sounds, visitors, or a '
            'different routine are common causes.',
      ));
    } else {
      insights.add(Insight(
        kind: InsightKind.weeklyTrend,
        tone: InsightTone.neutral,
        title: 'Steady week',
        body: '$dogName\'s calm time is holding around ${_pct(current)}% — '
            'a stable routine is doing its job.',
      ));
    }
  }

  // 2. Time-of-day pattern.
  final parts = dayPartCalmShares(hourly);
  if (parts.length >= 2) {
    final sorted = [...parts]..sort((a, b) => a.share.compareTo(b.share));
    final tensest = sorted.first;
    final calmest = sorted.last;
    if (calmest.share - tensest.share >= 0.10) {
      insights.add(Insight(
        kind: InsightKind.dayPart,
        tone: InsightTone.neutral,
        title: 'Calmest ${calmest.name}',
        body: '$dogName tends to be most relaxed ${calmest.name} and most '
            'tense ${tensest.name}. If you can, save exciting things for the '
            'calm window and keep the tense one low-key.',
      ));
    }
  }

  // 3. Activity ↔ calm association (median split; needs 3+ days each side).
  final withMotion = daily.where((d) => d.avgMotion != null && d.total > 0).toList();
  if (withMotion.length >= 6) {
    final motions = withMotion.map((d) => d.avgMotion!).toList()..sort();
    // Lower median so a two-cluster split (common with routine days) never
    // leaves the "active" side empty on ties.
    final median = motions[(motions.length - 1) ~/ 2];
    final active = withMotion.where((d) => d.avgMotion! > median).toList();
    final quiet = withMotion.where((d) => d.avgMotion! <= median).toList();
    final activeShare = calmShare(active);
    final quietShare = calmShare(quiet);
    if (active.length >= 3 && quiet.length >= 3 && activeShare != null && quietShare != null) {
      final delta = activeShare - quietShare;
      if (delta >= 0.10) {
        insights.add(Insight(
          kind: InsightKind.activity,
          tone: InsightTone.positive,
          title: 'Active days look like calmer days',
          body: 'On $dogName\'s more active days, calm time averages '
              '${_pct(activeShare)}% vs ${_pct(quietShare)}% on quieter days. '
              'Regular exercise seems to agree with $dogName.',
        ));
      } else if (delta <= -0.10) {
        insights.add(Insight(
          kind: InsightKind.activity,
          tone: InsightTone.neutral,
          title: 'Quieter days look like calmer days',
          body: 'On gentler days, $dogName\'s calm time averages '
              '${_pct(quietShare)}% vs ${_pct(activeShare)}% on busy ones. '
              'A slower pace may suit $dogName right now.',
        ));
      }
    }
  }

  // 4. Alert trend, this week vs last.
  final weekAgo = now.subtract(const Duration(days: 7));
  final twoWeeksAgo = now.subtract(const Duration(days: 14));
  final thisWeek = alerts.where((a) => a.createdAt.isAfter(weekAgo)).length;
  final lastWeek = alerts
      .where((a) => a.createdAt.isAfter(twoWeeksAgo) && !a.createdAt.isAfter(weekAgo))
      .length;
  if (thisWeek == 0 && lastWeek > 0) {
    insights.add(Insight(
      kind: InsightKind.alerts,
      tone: InsightTone.positive,
      title: 'No alerts this week',
      body: 'Down from $lastWeek last week — a genuinely good sign.',
    ));
  } else if (lastWeek > 0 && thisWeek < lastWeek) {
    insights.add(Insight(
      kind: InsightKind.alerts,
      tone: InsightTone.positive,
      title: 'Fewer alerts this week',
      body: '$thisWeek this week vs $lastWeek last week — rough moments are '
          'getting rarer.',
    ));
  } else if (thisWeek > lastWeek && thisWeek >= 3) {
    insights.add(Insight(
      kind: InsightKind.alerts,
      tone: InsightTone.attention,
      title: 'More alerts than usual',
      body: '$thisWeek alerts this week vs $lastWeek last week. If this keeps '
          'up, it\'s worth mentioning to your clinic.',
    ));
  }

  // 5. Data coverage caveat — thin data makes every trend above shakier.
  final recentDays = daily
      .where((d) => !d.day.isBefore(DateTime(now.year, now.month, now.day)
          .subtract(const Duration(days: 2))))
      .toList();
  final recentSamples = recentDays.fold<int>(0, (sum, d) => sum + d.total);
  if (recentSamples < 20) {
    insights.add(Insight(
      kind: InsightKind.coverage,
      tone: InsightTone.attention,
      title: 'Not much data lately',
      body: 'The harness has sent only a little data in the last few days, so '
          'trends are less reliable. Check the strap, battery, and Wi-Fi.',
    ));
  }

  return insights;
}

/// ADDED (QA): one-sentence story of the last 7 days ("how the week went").
/// Null until at least 3 days have data — no stories built on thin air.
String? weekStory(String dogName, List<DailyStressSummary> daily, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final start = today.subtract(const Duration(days: 6));
  final week = daily
      .where((d) => !d.day.isBefore(start) && !d.day.isAfter(today) && d.total > 0)
      .toList();
  if (week.length < 3) return null;

  const names = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
  ];
  final good = week.where((d) => (d.calmShare ?? 0) >= 0.8).length;
  var hardest = week.first;
  for (final d in week) {
    if ((d.calmShare ?? 1) < (hardest.calmShare ?? 1)) hardest = d;
  }

  if (good == week.length) {
    return '$dogName was mostly calm every day this week — a good week.';
  }
  final hardestName = names[hardest.day.weekday - 1];
  return '$dogName was mostly calm on $good of ${week.length} days this week; '
      '$hardestName was the hardest day.';
}
