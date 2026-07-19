import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:furfeel_mobile/data/settings_controller.dart';
import 'package:furfeel_mobile/models/models.dart';

import 'fakes.dart';

void main() {
  test('temperature formats in the preferred unit', () async {
    final controller = SettingsController(FakeRepository());
    expect(controller.formatTemperature(38.5), '38.5');
    expect(controller.temperatureUnitLabel, '°C');

    await controller.update(const UserSettings(temperatureUnit: 'f'));
    expect(controller.formatTemperature(38.5), '101.3');
    expect(controller.temperatureUnitLabel, '°F');
    expect(controller.formatTemperature(null), '—');
  });

  test('theme defaults to light and only system follows the OS', () {
    final controller = SettingsController(FakeRepository());
    // QA: new installs open in light regardless of OS brightness.
    expect(controller.settings.theme, 'light');
    expect(controller.themeMode, ThemeMode.light);

    controller.settings = const UserSettings(theme: 'dark');
    expect(controller.themeMode, ThemeMode.dark);

    controller.settings = const UserSettings(theme: 'system');
    expect(controller.themeMode, ThemeMode.system);

    // Unknown values fall back to light, never to the OS.
    controller.settings = UserSettings.fromMap(const {'theme': 'sepia'});
    expect(controller.themeMode, ThemeMode.light);
  });

  test('copyWith can clear quiet hours with explicit nulls', () {
    const settings =
        UserSettings(quietHoursStart: '22:00:00', quietHoursEnd: '07:00:00');
    final cleared = settings.copyWith(quietHoursStart: null, quietHoursEnd: null);
    expect(cleared.quietHoursStart, isNull);
    expect(cleared.quietHoursEnd, isNull);
    // Untouched fields survive copyWith.
    expect(settings.copyWith(theme: 'dark').quietHoursStart, '22:00:00');
  });
}
