import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furfeel_mobile/data/settings_controller.dart';
import 'package:furfeel_mobile/insights/month_summary.dart';
import 'package:furfeel_mobile/models/models.dart';
import 'package:furfeel_mobile/screens/home/chat_tab.dart';
import 'package:furfeel_mobile/screens/home/trends_tab.dart';

import 'fakes.dart';

const _dog = Dog(id: 'dog-1', ownerUserId: 'user-1', name: 'Biscuit');

DailyStressSummary day(
  int d, {
  int calm = 0,
  int mild = 0,
  int moderate = 0,
  int high = 0,
  int month = 10,
}) =>
    DailyStressSummary(
      day: DateTime(2026, month, d),
      calm: calm,
      mild: mild,
      moderate: moderate,
      high: high,
    );

void main() {
  group('dayLevel', () {
    test('no readings is null, never calm', () {
      expect(dayLevel(day(1)), isNull);
    });

    test('calm at the mostly-calm cutoff', () {
      expect(dayLevel(day(1, calm: 70, mild: 30)), StressLevel.calm);
    });

    test('below the cutoff takes the most common non-calm level', () {
      expect(dayLevel(day(1, calm: 58, mild: 27, moderate: 15)), StressLevel.mild);
      expect(dayLevel(day(1, calm: 60, moderate: 30, mild: 10)), StressLevel.moderate);
    });

    test('a tie goes to the higher level', () {
      expect(dayLevel(day(1, calm: 50, moderate: 25, high: 25)), StressLevel.high);
      expect(dayLevel(day(1, calm: 50, mild: 25, moderate: 25)), StressLevel.moderate);
    });
  });

  group('monthSummary', () {
    final now = DateTime(2026, 11, 5);
    ({String headline, String lede}) summary(
      List<DailyStressSummary> days, {
      DateTime? month,
      int alerts = 0,
      int run = 0,
    }) =>
        monthSummary(
          dogName: 'Biscuit',
          month: month ?? DateTime(2026, 10),
          days: days,
          alertCount: alerts,
          calmRun: run,
          now: now,
        );

    test('a mostly calm month says so, with counts', () {
      final result = summary(
        [for (var i = 1; i <= 8; i++) day(i, calm: 90, mild: 10)],
        alerts: 1,
      );
      expect(result.headline, 'A calm October for Biscuit');
      expect(result.lede, '8 calm days and 1 alert.');
    });

    test('the streak only shows on the current month', () {
      final days = [for (var i = 1; i <= 8; i++) day(i, calm: 90, month: 11)];
      expect(
        summary(days, month: DateTime(2026, 11), run: 5).lede,
        '8 calm days and 0 alerts, with 5 calm days in a row so far.',
      );
    });

    test('mixed and harder months', () {
      List<DailyStressSummary> mix(int calmDays) => [
            for (var i = 1; i <= 10; i++)
              i <= calmDays ? day(i, calm: 90) : day(i, calm: 10, high: 90),
          ];
      expect(summary(mix(5)).headline, 'A mixed October for Biscuit');
      expect(summary(mix(2)).headline, 'A harder October for Biscuit');
    });

    test('early days are honest about what is known', () {
      final current = summary(
        [day(1, calm: 90, month: 11), day(2, calm: 90, month: 11), day(3, calm: 9, month: 11)],
        month: DateTime(2026, 11),
      );
      expect(current.headline, 'Getting to know Biscuit');
      expect(current.lede, contains('3 days so far'));
      expect(summary([day(1, calm: 90)]).headline, 'Only 1 day of readings in October');
    });

    test('early in a month, a dog with history is not a new dog', () {
      ({String headline, String lede}) early(List<DailyStressSummary> days) =>
          monthSummary(
            dogName: 'Biscuit',
            month: DateTime(2026, 11),
            days: days,
            alertCount: 3,
            calmRun: 0,
            now: now,
            hasEarlierData: true,
          );
      final result = early([day(1, calm: 90, month: 11)]);
      expect(result.headline, 'November so far');
      expect(result.lede, '1 calm day and 3 alerts so far.');
      expect(early(const []).lede, 'No readings yet this month.');
    });

    test('an empty past month never reads as a good one', () {
      expect(summary(const []).headline, 'No readings in October');
    });
  });

  test('hardestHour picks the worst hour and ignores calm days', () {
    expect(hardestHour(List.filled(24, StressLevel.calm)), isNull);
    final hours = List<StressLevel?>.filled(24, null)
      ..[9] = StressLevel.mild
      ..[17] = StressLevel.moderate;
    expect(hardestHour(hours), 17);
  });

  testWidgets('tapping a day opens its panel and links to the vet', (tester) async {
    final today = DateTime.now();
    final repo = FakeRepository(
      dogs: const [_dog],
      dailySummaries: [
        DailyStressSummary(
          day: DateTime(today.year, today.month, 1),
          calm: 10,
          mild: 90,
          moderate: 0,
          high: 0,
        ),
      ],
    );
    await tester.pumpWidget(SettingsScope(
      controller: SettingsController(repo),
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(
          body: TrendsTab(
            repository: repo,
            dog: _dog,
            daily: repo.dailySummaries,
            hourly: const [],
            alerts: [
              for (final id in ['a1', 'a2'])
                Alert(
                  id: id,
                  dogId: 'dog-1',
                  severity: 'warning',
                  type: 'device_offline',
                  message: 'Offline',
                  status: 'acknowledged',
                  createdAt: DateTime(today.year, today.month, 1, 9),
                ),
            ],
            onRefresh: () async {},
          ),
        ),
      ),
    ));
    // Shaped like the page while the month loads, with no empty calendar.
    expect(find.bySemanticsLabel('Loading trends'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Loading trends'), findsNothing);

    final dayOne = find.bySemanticsLabel(RegExp(r' 1, A mild day, has an alert$'));
    expect(dayOne, findsOneWidget);
    await tester.tap(dayOne);
    await tester.pumpAndSettle();
    expect(find.text('A mild day'), findsOneWidget);
    expect(
      find.textContaining('2 alerts · Device stopped sending data', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('No readings yet'), findsNothing);

    await tester.tap(find.text('Message vet about this day'));
    await tester.pumpAndSettle();
    expect(find.byType(DogChatPage), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, startsWith('About '));
  });
}
