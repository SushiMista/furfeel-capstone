import 'package:flutter_test/flutter_test.dart';
import 'package:furfeel_mobile/insights/owner_moments.dart';
import 'package:furfeel_mobile/models/models.dart';

DailyStressSummary day(DateTime d, {int calm = 0, int mild = 0, int high = 0}) =>
    DailyStressSummary(day: d, calm: calm, mild: mild, moderate: 0, high: high);

StressClassification cls(DateTime at, StressLevel level) => StressClassification(
      id: 'c-${at.millisecondsSinceEpoch}-${level.name}',
      dogId: 'dog-1',
      stressLevel: level,
      createdAt: at,
    );

void main() {
  final now = DateTime(2026, 7, 18, 10);

  group('setupProgress / setupComplete', () {
    test('essentials are harness + first reading; clinic never blocks done', () {
      final missing =
          setupProgress(hasDevice: false, hasClinic: false, hasReading: false);
      expect(setupComplete(missing), isFalse);

      final noClinic =
          setupProgress(hasDevice: true, hasClinic: false, hasReading: true);
      expect(setupComplete(noClinic), isTrue);

      final noReading =
          setupProgress(hasDevice: true, hasClinic: true, hasReading: false);
      expect(setupComplete(noReading), isFalse);
    });
  });

  group('calmStreak', () {
    test('counts consecutive mostly-calm days ending now', () {
      final daily = [
        day(DateTime(2026, 7, 18), calm: 9, mild: 1), // today, 90%
        day(DateTime(2026, 7, 17), calm: 8, mild: 2), // 80%
        day(DateTime(2026, 7, 16), calm: 7, mild: 3), // 70% — still counts
        day(DateTime(2026, 7, 15), calm: 3, high: 7), // breaks the run
        day(DateTime(2026, 7, 14), calm: 10),
      ];
      expect(calmStreak(daily, now), 3);
    });

    test('an empty today does not break the streak', () {
      final daily = [
        day(DateTime(2026, 7, 17), calm: 10),
        day(DateTime(2026, 7, 16), calm: 10),
      ];
      expect(calmStreak(daily, now), 2);
    });

    test('no data or below threshold = no streak', () {
      expect(calmStreak([], now), 0);
      expect(calmStreak([day(DateTime(2026, 7, 18), calm: 1, high: 9)], now), 0);
    });

    test('a gap day (no data) ends the streak', () {
      final daily = [
        day(DateTime(2026, 7, 18), calm: 10),
        // 17th missing entirely
        day(DateTime(2026, 7, 16), calm: 10),
      ];
      expect(calmStreak(daily, now), 1);
    });
  });

  group('hourlyDominantLevels', () {
    test('dominant level per hour, gaps stay null, ties go to the higher level',
        () {
      final today = DateTime(2026, 7, 18);
      final hours = hourlyDominantLevels([
        cls(DateTime(2026, 7, 18, 8, 0), StressLevel.calm),
        cls(DateTime(2026, 7, 18, 8, 10), StressLevel.calm),
        cls(DateTime(2026, 7, 18, 8, 20), StressLevel.high),
        // Hour 9: tie calm/mild -> mild (elevated wins ties).
        cls(DateTime(2026, 7, 18, 9, 0), StressLevel.calm),
        cls(DateTime(2026, 7, 18, 9, 30), StressLevel.mild),
        // Yesterday's readings never leak into today.
        cls(DateTime(2026, 7, 17, 8, 0), StressLevel.high),
      ], today);

      expect(hours, hasLength(24));
      expect(hours[8], StressLevel.calm);
      expect(hours[9], StressLevel.mild);
      expect(hours[7], isNull);
    });
  });

  group('Dog.isBirthday', () {
    test('matches month + day, false without a parsable birthdate', () {
      const birthday = Dog(
          id: 'd', ownerUserId: 'u', name: 'B', birthdate: '2020-07-18');
      const notToday = Dog(
          id: 'd', ownerUserId: 'u', name: 'B', birthdate: '2020-01-02');
      const none = Dog(id: 'd', ownerUserId: 'u', name: 'B');
      expect(birthday.isBirthday(now), isTrue);
      expect(notToday.isBirthday(now), isFalse);
      expect(none.isBirthday(now), isFalse);
    });
  });
}
