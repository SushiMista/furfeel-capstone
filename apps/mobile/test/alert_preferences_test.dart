import 'package:flutter_test/flutter_test.dart';
import 'package:furfeel_mobile/models/models.dart';

void main() {
  test('Settings switches mute the alert types the app actually checks', () {
    final muted = const UserSettings().withAlertCategoryEnabled('stress', false);
    expect(muted.mutedAlertTypes, ['moderate_stress', 'high_stress']);
    expect(muted.isAlertCategoryEnabled('stress'), isFalse);
    expect(muted.isAlertCategoryEnabled('battery'), isTrue);
    expect(
      muted.withAlertCategoryEnabled('stress', true).mutedAlertTypes,
      isEmpty,
    );
  });

  test('quiet hours handle spans past midnight and turning off', () {
    const overnight = UserSettings(
      quietHoursStart: '22:00:00',
      quietHoursEnd: '07:00:00',
    );
    expect(overnight.isQuietAt(DateTime(2026, 1, 1, 23)), isTrue);
    expect(overnight.isQuietAt(DateTime(2026, 1, 1, 6, 59)), isTrue);
    expect(overnight.isQuietAt(DateTime(2026, 1, 1, 7)), isFalse);
    expect(overnight.isQuietAt(DateTime(2026, 1, 1, 12)), isFalse);

    const daytime = UserSettings(
      quietHoursStart: '09:00:00',
      quietHoursEnd: '17:00:00',
    );
    expect(daytime.isQuietAt(DateTime(2026, 1, 1, 12)), isTrue);
    expect(daytime.isQuietAt(DateTime(2026, 1, 1, 18)), isFalse);

    expect(const UserSettings().isQuietAt(DateTime(2026, 1, 1, 23)), isFalse);
  });
}
