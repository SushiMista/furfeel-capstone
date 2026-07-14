import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/settings_controller.dart';
import '../theme/furfeel_tokens.dart';
import '../util/motion.dart';
import 'about_pages.dart';

/// ADDED: Settings (docs/04, backed by user_settings): theme applied app-wide,
/// temperature unit applied to every vital, notification toggles + quiet
/// hours, plus About / Privacy / How FurFeel works.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = SettingsScope.of(context);
    final settings = controller.settings;
    final textTheme = Theme.of(context).textTheme;

    TimeOfDay? parseTime(String? hhmmss) {
      if (hhmmss == null) return null;
      final parts = hhmmss.split(':');
      if (parts.length < 2) return null;
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }

    String encodeTime(TimeOfDay t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

    Future<void> pickQuietHour({required bool start}) async {
      final current = parseTime(start ? settings.quietHoursStart : settings.quietHoursEnd);
      final picked = await showTimePicker(
        context: context,
        initialTime: current ?? TimeOfDay(hour: start ? 22 : 7, minute: 0),
      );
      if (picked == null) return;
      HapticFeedback.selectionClick();
      controller.update(
        start
            ? settings.copyWith(quietHoursStart: encodeTime(picked))
            : settings.copyWith(quietHoursEnd: encodeTime(picked)),
      );
    }

    final quietStart = parseTime(settings.quietHoursStart);
    final quietEnd = parseTime(settings.quietHoursEnd);
    final quietHoursOn = quietStart != null && quietEnd != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(FurFeelTokens.space4),
        children: [
          Text('APPEARANCE', style: textTheme.labelSmall).entrance(context),
          const SizedBox(height: FurFeelTokens.space2),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(FurFeelTokens.space4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'system',
                        label: Text('System'),
                        icon: Icon(Icons.brightness_auto_outlined),
                      ),
                      ButtonSegment(
                        value: 'light',
                        label: Text('Light'),
                        icon: Icon(Icons.light_mode_outlined),
                      ),
                      ButtonSegment(
                        value: 'dark',
                        label: Text('Dark'),
                        icon: Icon(Icons.dark_mode_outlined),
                      ),
                    ],
                    selected: {settings.theme},
                    onSelectionChanged: (selection) {
                      HapticFeedback.selectionClick();
                      controller.update(settings.copyWith(theme: selection.first));
                    },
                  ),
                ],
              ),
            ),
          ).entrance(context, index: 1),
          const SizedBox(height: FurFeelTokens.space5),
          Text('UNITS', style: textTheme.labelSmall).entrance(context, index: 2),
          const SizedBox(height: FurFeelTokens.space2),
          Card(
            child: ListTile(
              leading: Icon(Icons.thermostat_outlined, color: FurFeelTokens.brand),
              title: const Text('Temperature'),
              subtitle: const Text('Used for every reading in the app'),
              trailing: SegmentedButton<String>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 'c', label: Text('°C')),
                  ButtonSegment(value: 'f', label: Text('°F')),
                ],
                selected: {settings.temperatureUnit},
                onSelectionChanged: (selection) {
                  HapticFeedback.selectionClick();
                  controller.update(settings.copyWith(temperatureUnit: selection.first));
                },
              ),
            ),
          ).entrance(context, index: 3),
          const SizedBox(height: FurFeelTokens.space5),
          Text('NOTIFICATIONS', style: textTheme.labelSmall).entrance(context, index: 4),
          const SizedBox(height: FurFeelTokens.space2),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: Icon(Icons.notifications_outlined, color: FurFeelTokens.brand),
                  title: const Text('Push notifications'),
                  subtitle: const Text('Stress alerts and harness status'),
                  value: settings.notificationsEnabled,
                  onChanged: (on) {
                    HapticFeedback.selectionClick();
                    controller.update(settings.copyWith(notificationsEnabled: on));
                  },
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                SwitchListTile(
                  secondary: Icon(Icons.bedtime_outlined, color: FurFeelTokens.brand),
                  title: const Text('Quiet hours'),
                  subtitle: const Text('Mute non-critical alerts overnight'),
                  value: quietHoursOn,
                  onChanged: settings.notificationsEnabled
                      ? (on) {
                          HapticFeedback.selectionClick();
                          controller.update(on
                              ? settings.copyWith(
                                  quietHoursStart: '22:00:00', quietHoursEnd: '07:00:00')
                              : settings.copyWith(
                                  quietHoursStart: null, quietHoursEnd: null));
                        }
                      : null,
                ),
                if (quietHoursOn) ...[
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    title: const Text('From'),
                    trailing: Text(
                      quietStart.format(context),
                      style: TextStyle(color: FurFeelTokens.brand, fontWeight: FontWeight.w600),
                    ),
                    onTap: () => pickQuietHour(start: true),
                  ),
                  ListTile(
                    title: const Text('Until'),
                    trailing: Text(
                      quietEnd.format(context),
                      style: TextStyle(color: FurFeelTokens.brand, fontWeight: FontWeight.w600),
                    ),
                    onTap: () => pickQuietHour(start: false),
                  ),
                ],
              ],
            ),
          ).entrance(context, index: 5),
          const SizedBox(height: FurFeelTokens.space5),
          Text('ABOUT', style: textTheme.labelSmall).entrance(context, index: 6),
          const SizedBox(height: FurFeelTokens.space2),
          Card(
            child: Column(
              children: [
                _LinkTile(
                  icon: Icons.pets_outlined,
                  title: 'How FurFeel works',
                  page: const HowItWorksPage(),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _LinkTile(
                  icon: Icons.lock_outline,
                  title: 'Privacy',
                  page: const PrivacyPage(),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _LinkTile(
                  icon: Icons.info_outline,
                  title: 'About FurFeel',
                  page: const AboutPage(),
                ),
              ],
            ),
          ).entrance(context, index: 7),
        ],
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({required this.icon, required this.title, required this.page});

  final IconData icon;
  final String title;
  final Widget page;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: FurFeelTokens.brand),
      title: Text(title),
      trailing: Icon(Icons.chevron_right, color: FurFeelTokens.inkMuted),
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => page)),
    );
  }
}
