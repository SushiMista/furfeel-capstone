import 'package:flutter_test/flutter_test.dart';
import 'package:furfeel_mobile/insights/insights.dart';
import 'package:furfeel_mobile/models/models.dart';

final _now = DateTime(2026, 7, 12, 12);

DailyStressSummary day(int daysAgo, {int calm = 0, int mild = 0, int moderate = 0, int high = 0, double? motion}) =>
    DailyStressSummary(
      day: DateTime(2026, 7, 12).subtract(Duration(days: daysAgo)),
      calm: calm,
      mild: mild,
      moderate: moderate,
      high: high,
      avgMotion: motion,
    );

HourlyStressBucket bucket(int hour, {int calm = 0, int mild = 0, int moderate = 0, int high = 0}) =>
    HourlyStressBucket(hour: hour, calm: calm, mild: mild, moderate: moderate, high: high);

Alert alertAt(DateTime at) => Alert(
      id: 'a-${at.millisecondsSinceEpoch}',
      dogId: 'dog-1',
      severity: 'warning',
      type: 'high_stress',
      message: 'x',
      status: 'open',
      createdAt: at,
    );

Insight? ofKind(List<Insight> insights, InsightKind kind) {
  for (final i in insights) {
    if (i.kind == kind) return i;
  }
  return null;
}

void main() {
  group('weekOverWeekCalm', () {
    test('splits the last 14 days into two 7-day windows', () {
      final daily = [
        for (var i = 0; i < 7; i++) day(i, calm: 9, high: 1), // this week: 90%
        for (var i = 7; i < 14; i++) day(i, calm: 5, high: 5), // last week: 50%
      ];
      final result = weekOverWeekCalm(daily, _now);
      expect(result.current, closeTo(0.9, 0.001));
      expect(result.previous, closeTo(0.5, 0.001));
    });

    test('returns nulls when a window has no data', () {
      final result = weekOverWeekCalm([day(0, calm: 5)], _now);
      expect(result.current, isNotNull);
      expect(result.previous, isNull);
    });
  });

  group('dayPartCalmShares', () {
    test('skips day-parts with too few samples', () {
      final hourly = [
        bucket(7, calm: 40, high: 10), // morning: 50 samples, 80% calm
        bucket(20, calm: 2, high: 2), // evening: only 4 samples — skipped
      ];
      final parts = dayPartCalmShares(hourly);
      expect(parts, hasLength(1));
      expect(parts.first.name, 'in the morning');
      expect(parts.first.share, closeTo(0.8, 0.001));
    });
  });

  group('buildInsights', () {
    test('improving week produces a positive trend insight', () {
      final insights = buildInsights(
        dogName: 'Biscuit',
        daily: [
          for (var i = 0; i < 7; i++) day(i, calm: 9, high: 1),
          for (var i = 7; i < 14; i++) day(i, calm: 5, high: 5),
        ],
        hourly: const [],
        alerts: const [],
        now: _now,
      );
      final trend = ofKind(insights, InsightKind.weeklyTrend);
      expect(trend, isNotNull);
      expect(trend!.tone, InsightTone.positive);
      expect(trend.body, contains('90%'));
      expect(trend.body, contains('50%'));
    });

    test('active days calmer than quiet days produces the activity insight', () {
      final insights = buildInsights(
        dogName: 'Biscuit',
        daily: [
          // Active days: 90% calm. Quiet days: 40% calm.
          for (var i = 0; i < 4; i++) day(i, calm: 90, high: 10, motion: 0.8),
          for (var i = 4; i < 8; i++) day(i, calm: 40, high: 60, motion: 0.1),
        ],
        hourly: const [],
        alerts: const [],
        now: _now,
      );
      final activity = ofKind(insights, InsightKind.activity);
      expect(activity, isNotNull);
      expect(activity!.tone, InsightTone.positive);
      expect(activity.body, contains('more active days'));
    });

    test('fewer alerts than last week is celebrated', () {
      final insights = buildInsights(
        dogName: 'Biscuit',
        daily: const [],
        hourly: const [],
        alerts: [
          alertAt(_now.subtract(const Duration(days: 1))), // this week: 1
          alertAt(_now.subtract(const Duration(days: 8))), // last week: 3
          alertAt(_now.subtract(const Duration(days: 9))),
          alertAt(_now.subtract(const Duration(days: 10))),
        ],
        now: _now,
      );
      final alerts = ofKind(insights, InsightKind.alerts);
      expect(alerts, isNotNull);
      expect(alerts!.tone, InsightTone.positive);
    });

    test('sparse recent data adds a coverage caveat', () {
      final insights = buildInsights(
        dogName: 'Biscuit',
        daily: [day(0, calm: 3), day(1, calm: 2)], // almost nothing recent
        hourly: const [],
        alerts: const [],
        now: _now,
      );
      expect(ofKind(insights, InsightKind.coverage), isNotNull);
    });

    test('emits nothing it cannot back with data', () {
      final insights = buildInsights(
        dogName: 'Biscuit',
        daily: const [],
        hourly: const [],
        alerts: const [],
        now: _now,
      );
      // Only the coverage caveat is legitimate here.
      expect(insights.where((i) => i.kind != InsightKind.coverage), isEmpty);
    });

    test('never uses diagnosis language', () {
      final insights = buildInsights(
        dogName: 'Biscuit',
        daily: [
          for (var i = 0; i < 7; i++) day(i, calm: 2, high: 8, motion: 0.8),
          for (var i = 7; i < 14; i++) day(i, calm: 9, high: 1, motion: 0.1),
        ],
        hourly: [bucket(8, calm: 10, high: 40), bucket(20, calm: 45, high: 5)],
        alerts: [for (var i = 0; i < 5; i++) alertAt(_now.subtract(Duration(days: i)))],
        now: _now,
      );
      for (final i in insights) {
        final text = '${i.title} ${i.body}'.toLowerCase();
        expect(text, isNot(contains('diagnos')));
        expect(text, isNot(contains('disease')));
        expect(text, isNot(contains('treatment')));
      }
    });
  });

  group('weekStory', () {
    DailyStressSummary day(int daysAgo, int calm, int high) {
      final now = DateTime.now();
      return DailyStressSummary(
        day: DateTime(now.year, now.month, now.day).subtract(Duration(days: daysAgo)),
        calm: calm,
        mild: 0,
        moderate: 0,
        high: high,
      );
    }

    test('names the hardest day and counts the calm ones', () {
      final daily = [day(0, 90, 10), day(1, 40, 60), day(2, 95, 5), day(3, 85, 15)];
      final story = weekStory('Biscuit', daily, DateTime.now())!;
      expect(story, contains('3 of 4 days'));
      expect(story, contains('hardest day'));
    });

    test('celebrates an all-calm week', () {
      final daily = [for (var i = 0; i < 7; i++) day(i, 95, 5)];
      expect(weekStory('Biscuit', daily, DateTime.now()), contains('a good week'));
    });

    test('stays quiet with fewer than 3 days of data', () {
      expect(weekStory('Biscuit', [day(0, 90, 10)], DateTime.now()), isNull);
    });
  });
}
