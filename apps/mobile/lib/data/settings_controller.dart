import 'package:flutter/widgets.dart';

import '../models/models.dart';
import 'furfeel_repository.dart';

/// ADDED: app-wide account state (docs/04 Account, Settings & Personalization).
/// Owns the signed-in user's profile + user_settings row and applies them
/// everywhere: theme (via the app root), temperature unit (via [formatTemperature]),
/// and the greeting name. Saves are optimistic — the UI flips instantly and the
/// row is written behind it.
class SettingsController extends ChangeNotifier {
  SettingsController(this._repository);

  final FurFeelRepository _repository;

  /// Exposed for screens that reach settings via the scope but also need to
  /// persist profile fields (e.g. the contact-field editors).
  FurFeelRepository get repository => _repository;

  UserProfile? profile;
  UserSettings settings = const UserSettings();
  bool loaded = false;

  Future<void> load() async {
    try {
      final results = await Future.wait<Object?>([
        _repository.fetchMyProfile(),
        _repository.fetchMySettings(),
      ]);
      profile = results[0] as UserProfile;
      settings = results[1] as UserSettings;
    } catch (_) {
      // Profile is a nicety, never a gate: greeting and settings fall back to
      // defaults and the app stays usable offline.
    }
    loaded = true;
    notifyListeners();
  }

  void clear() {
    profile = null;
    settings = const UserSettings();
    loaded = false;
    notifyListeners();
  }

  /// True when the app should render dark. 'system' follows the OS; anything
  /// unexpected falls back to light (QA: light is the default experience).
  bool resolveDark(Brightness platformBrightness) => switch (settings.theme) {
        'dark' => true,
        'system' => platformBrightness == Brightness.dark,
        _ => false,
      };

  Future<void> update(UserSettings next) async {
    settings = next;
    notifyListeners();
    try {
      await _repository.saveMySettings(next);
    } catch (_) {
      // Keep the optimistic value; the next successful save wins.
    }
  }

  void setProfile(UserProfile next) {
    profile = next;
    notifyListeners();
  }

  // ---- Temperature unit, applied to every vital (docs/04 Settings) ----

  bool get useFahrenheit => settings.temperatureUnit == 'f';

  String get temperatureUnitLabel => useFahrenheit ? '°F' : '°C';

  /// Formats a Celsius reading in the preferred unit, without the unit suffix
  /// (vital cards render the unit separately).
  String formatTemperature(double? celsius) {
    if (celsius == null) return '—';
    final value = useFahrenheit ? celsius * 9 / 5 + 32 : celsius;
    return value.toStringAsFixed(1);
  }
}

/// Inherited access so any widget can read the controller without plumbing.
class SettingsScope extends InheritedNotifier<SettingsController> {
  const SettingsScope({super.key, required SettingsController controller, required super.child})
      : super(notifier: controller);

  static SettingsController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SettingsScope>()!.notifier!;
}
