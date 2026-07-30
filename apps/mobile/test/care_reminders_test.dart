import 'package:flutter_test/flutter_test.dart';
import 'package:furfeel_mobile/data/reminder_scheduler.dart';
import 'package:furfeel_mobile/models/models.dart';
import 'package:furfeel_mobile/widgets/reminders_section.dart';

import 'fakes.dart';

void main() {
  group('effectiveFireTime (quiet hours)', () {
    test('no quiet hours -> unchanged', () {
      final due = DateTime(2026, 8, 1, 23, 30);
      expect(effectiveFireTime(due, null, null), due);
    });

    test('time outside window -> unchanged', () {
      final due = DateTime(2026, 8, 1, 9, 0);
      expect(effectiveFireTime(due, '22:00', '07:00'), due);
    });

    test('overnight window defers to end (next morning)', () {
      // 23:30 falls inside 22:00->07:00, so it moves to 07:00 next day.
      final due = DateTime(2026, 8, 1, 23, 30);
      expect(effectiveFireTime(due, '22:00:00', '07:00:00'),
          DateTime(2026, 8, 2, 7, 0));
    });

    test('early-morning inside overnight window defers to same-day end', () {
      // 03:00 is inside 22:00->07:00; end 07:00 is later the same day.
      final due = DateTime(2026, 8, 1, 3, 0);
      expect(effectiveFireTime(due, '22:00', '07:00'),
          DateTime(2026, 8, 1, 7, 0));
    });

    test('daytime window defers to its end', () {
      final due = DateTime(2026, 8, 1, 13, 0);
      expect(effectiveFireTime(due, '12:00', '14:00'),
          DateTime(2026, 8, 1, 14, 0));
    });
  });

  group('reminder repository round-trip', () {
    test('save then fetch returns the active reminder, delete removes it', () async {
      final repo = FakeRepository();
      final saved = await repo.saveReminder(
        dogId: 'dog-1',
        title: 'Morning meds',
        dueAt: DateTime(2026, 8, 1, 8, 0),
        repeat: ReminderRepeat.daily,
      );

      var list = await repo.fetchReminders('dog-1');
      expect(list, hasLength(1));
      expect(list.single.title, 'Morning meds');
      expect(list.single.repeat, ReminderRepeat.daily);

      // Scoped to the dog.
      expect(await repo.fetchReminders('other-dog'), isEmpty);

      await repo.deleteReminder(saved.id);
      list = await repo.fetchReminders('dog-1');
      expect(list, isEmpty);
    });
  });

  test('describeReminderSchedule reads naturally', () {
    final daily = CareReminder(
      id: 'a',
      dogId: 'd',
      title: 't',
      dueAt: DateTime(2026, 8, 1, 8, 5),
      repeat: ReminderRepeat.daily,
      active: true,
    );
    expect(describeReminderSchedule(daily), 'Every day at 08:05');
  });
}
