import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/settings_controller.dart';
import '../theme/furfeel_tokens.dart';
import '../util/motion.dart';
import '../widgets/settings_group.dart';
import 'about_pages.dart';

/// Settings — categorized into clear sections.
///
/// Sections:
///   ACCOUNT        — Edit Profile (→ AccountPage, passed from caller),
///                    Phone Number, Emergency Contact (inline dialogs)
///   APPEARANCE     — Light / Dark / System theme
///   NOTIFICATIONS  — Push master toggle + per-type toggles + quiet hours
///   UNITS          — Temperature °C/°F, Weight kg/lbs (placeholder)
///   PRIVACY & SECURITY — Change Password, Delete Account (→ AccountPage)
///   ABOUT          — How it works, Privacy, About FurFeel
///
/// [onChangePassword] and [onDeleteAccount] are optional callbacks; when null
/// the rows show a "coming soon" snackbar (safe before AccountPage is wired).
class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    this.onEditProfile,
    this.onChangePassword,
    this.onDeleteAccount,
  });

  /// Open AccountPage / profile editor.
  final VoidCallback? onEditProfile;

  /// Trigger Change Password flow.
  final VoidCallback? onChangePassword;

  /// Trigger Delete Account flow.
  final VoidCallback? onDeleteAccount;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Per-type notification toggles — UI only until wired to user_settings
  bool _healthAlerts = true;
  bool _stressAlerts = true;
  bool _batteryAlerts = true;

  // Weight unit — UI only until added to UserSettings model
  String _weightUnit = 'kg';

  TimeOfDay? _parseTime(String? hhmmss) {
    if (hhmmss == null) return null;
    final parts = hhmmss.split(':');
    if (parts.length < 2) return null;
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _encodeTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  Future<void> _pickQuietHour(SettingsController ctrl,
      {required bool start}) async {
    final s = ctrl.settings;
    final current = _parseTime(start ? s.quietHoursStart : s.quietHoursEnd);
    final picked = await showTimePicker(
      context: context,
      initialTime: current ?? TimeOfDay(hour: start ? 22 : 7, minute: 0),
    );
    if (picked == null || !mounted) return;
    HapticFeedback.selectionClick();
    ctrl.update(start
        ? s.copyWith(quietHoursStart: _encodeTime(picked))
        : s.copyWith(quietHoursEnd: _encodeTime(picked)));
  }

  Future<void> _editField(
      BuildContext context, String label, String hint) async {
    final ctrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(label),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label saved (database wiring coming soon)'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }


  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = SettingsScope.of(context);
    final s = ctrl.settings;
    final textTheme = Theme.of(context).textTheme;

    final quietStart = _parseTime(s.quietHoursStart);
    final quietEnd = _parseTime(s.quietHoursEnd);
    final quietHoursOn = quietStart != null && quietEnd != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(FurFeelTokens.space4),
        children: [
          // ────────────────────────────────────────────────────────────
          // ACCOUNT
          // ────────────────────────────────────────────────────────────
          _Label('ACCOUNT').entrance(context),
          const SizedBox(height: FurFeelTokens.space2),
          SettingsGroup(
            children: [
              SettingsRow(
                icon: Icons.manage_accounts_outlined,
                title: 'Edit Profile',
                subtitle: 'Name, photo',
                onTap: widget.onEditProfile ??
                    () => _snack('Open via Profile → your name card'),
              ),
              SettingsRow(
                icon: Icons.phone_outlined,
                title: 'Phone Number',
                subtitle: 'Not set',
                onTap: () =>
                    _editField(context, 'Phone Number', '+63 9XX XXX XXXX'),
              ),
              SettingsRow(
                icon: Icons.emergency_outlined,
                iconBackground: FurFeelTokens.warmSoft,
                iconColor: FurFeelTokens.warm,
                title: 'Emergency Contact',
                subtitle: 'Not set',
                onTap: () =>
                    _editField(context, 'Emergency Contact', 'Name and number'),
              ),
            ],
          ).entrance(context, index: 1),
          const SizedBox(height: FurFeelTokens.space5),

          // ────────────────────────────────────────────────────────────
          // APPEARANCE
          // ────────────────────────────────────────────────────────────
          _Label('APPEARANCE').entrance(context, index: 2),
          const SizedBox(height: FurFeelTokens.space2),
          SettingsGroup(
            children: [
              Padding(
                padding: const EdgeInsets.all(FurFeelTokens.space4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: FurFeelTokens.brandSoft,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.palette_outlined,
                              size: 18, color: FurFeelTokens.brand),
                        ),
                        const SizedBox(width: FurFeelTokens.space3),
                        Text('Theme',
                            style: textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w500)),
                      ],
                    ),
                    const SizedBox(height: FurFeelTokens.space3),
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
                      selected: {s.theme},
                      onSelectionChanged: (sel) {
                        HapticFeedback.selectionClick();
                        ctrl.update(s.copyWith(theme: sel.first));
                      },
                    ),
                  ],
                ),
              ),
            ],
          ).entrance(context, index: 3),
          const SizedBox(height: FurFeelTokens.space5),

          // ────────────────────────────────────────────────────────────
          // NOTIFICATIONS
          // ────────────────────────────────────────────────────────────
          _Label('NOTIFICATIONS').entrance(context, index: 4),
          const SizedBox(height: FurFeelTokens.space2),
          SettingsGroup(
            children: [
              _SwitchRow(
                icon: Icons.notifications_outlined,
                title: 'Push Notifications',
                subtitle: 'All alerts from FurFeel',
                value: s.notificationsEnabled,
                onChanged: (on) {
                  HapticFeedback.selectionClick();
                  ctrl.update(s.copyWith(notificationsEnabled: on));
                },
              ),
              _SwitchRow(
                icon: Icons.favorite_outline,
                iconColor: FurFeelTokens.statusHighFg,
                iconBackground: FurFeelTokens.statusHighBg,
                title: 'Health Alerts',
                subtitle: 'Heart rate, temperature anomalies',
                value: s.notificationsEnabled && _healthAlerts,
                onChanged: s.notificationsEnabled
                    ? (on) => setState(() => _healthAlerts = on)
                    : null,
              ),
              _SwitchRow(
                icon: Icons.psychology_outlined,
                iconColor: FurFeelTokens.statusModerateFg,
                iconBackground: FurFeelTokens.statusModerateBg,
                title: 'Stress Alerts',
                subtitle: 'Moderate and high stress detections',
                value: s.notificationsEnabled && _stressAlerts,
                onChanged: s.notificationsEnabled
                    ? (on) => setState(() => _stressAlerts = on)
                    : null,
              ),
              _SwitchRow(
                icon: Icons.battery_alert_outlined,
                iconColor: FurFeelTokens.statusMildFg,
                iconBackground: FurFeelTokens.statusMildBg,
                title: 'Battery Alerts',
                subtitle: 'Low harness battery warnings',
                value: s.notificationsEnabled && _batteryAlerts,
                onChanged: s.notificationsEnabled
                    ? (on) => setState(() => _batteryAlerts = on)
                    : null,
              ),
              _SwitchRow(
                icon: Icons.bedtime_outlined,
                title: 'Quiet Hours',
                subtitle: 'Mute non-critical alerts overnight',
                value: quietHoursOn,
                onChanged: s.notificationsEnabled
                    ? (on) {
                        HapticFeedback.selectionClick();
                        ctrl.update(on
                            ? s.copyWith(
                                quietHoursStart: '22:00:00',
                                quietHoursEnd: '07:00:00')
                            : s.copyWith(
                                quietHoursStart: null,
                                quietHoursEnd: null));
                      }
                    : null,
              ),
              if (quietHoursOn) ...[
                _TimeRow(
                  icon: Icons.wb_twilight_outlined,
                  label: 'From',
                  value: quietStart.format(context),
                  onTap: () => _pickQuietHour(ctrl, start: true),
                ),
                _TimeRow(
                  icon: Icons.wb_sunny_outlined,
                  label: 'Until',
                  value: quietEnd.format(context),
                  onTap: () => _pickQuietHour(ctrl, start: false),
                ),
              ],
            ],
          ).entrance(context, index: 5),
          const SizedBox(height: FurFeelTokens.space5),

          // ────────────────────────────────────────────────────────────
          // UNITS
          // ────────────────────────────────────────────────────────────
          _Label('UNITS').entrance(context, index: 6),
          const SizedBox(height: FurFeelTokens.space2),
          SettingsGroup(
            children: [
              _UnitRow(
                icon: Icons.thermostat_outlined,
                label: 'Temperature',
                subtitle: 'Used for every vital reading',
                segments: const [
                  ButtonSegment(value: 'c', label: Text('°C')),
                  ButtonSegment(value: 'f', label: Text('°F')),
                ],
                selected: s.temperatureUnit,
                onChanged: (v) {
                  HapticFeedback.selectionClick();
                  ctrl.update(s.copyWith(temperatureUnit: v));
                },
              ),
              _UnitRow(
                icon: Icons.monitor_weight_outlined,
                label: 'Weight',
                subtitle: 'Dog weight display unit',
                segments: const [
                  ButtonSegment(value: 'kg', label: Text('kg')),
                  ButtonSegment(value: 'lbs', label: Text('lbs')),
                ],
                selected: _weightUnit,
                onChanged: (v) => setState(() => _weightUnit = v),
              ),
            ],
          ).entrance(context, index: 7),
          const SizedBox(height: FurFeelTokens.space5),

          // ────────────────────────────────────────────────────────────
          // PRIVACY & SECURITY
          // ────────────────────────────────────────────────────────────
          _Label('PRIVACY & SECURITY').entrance(context, index: 8),
          const SizedBox(height: FurFeelTokens.space2),
          SettingsGroup(
            children: [
              SettingsRow(
                icon: Icons.lock_reset_outlined,
                title: 'Change Password',
                onTap: widget.onChangePassword ??
                    () => _snack('Open via Profile → your name card → Change Password'),
              ),
              SettingsRow(
                icon: Icons.no_accounts_outlined,
                iconBackground: FurFeelTokens.statusHighBg,
                iconColor: FurFeelTokens.statusHighFg,
                title: 'Delete Account',
                destructive: true,
                onTap: widget.onDeleteAccount ??
                    () => _snack('Open via Profile → your name card → Delete Account'),
              ),
            ],
          ).entrance(context, index: 9),
          const SizedBox(height: FurFeelTokens.space5),

          // ────────────────────────────────────────────────────────────
          // ABOUT
          // ────────────────────────────────────────────────────────────
          _Label('ABOUT').entrance(context, index: 10),
          const SizedBox(height: FurFeelTokens.space2),
          SettingsGroup(
            children: [
              SettingsRow(
                icon: Icons.pets_outlined,
                title: 'How FurFeel works',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                      builder: (_) => const HowItWorksPage()),
                ),
              ),
              SettingsRow(
                icon: Icons.lock_outline,
                title: 'Privacy',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                      builder: (_) => const PrivacyPage()),
                ),
              ),
              SettingsRow(
                icon: Icons.info_outline,
                title: 'About FurFeel',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                      builder: (_) => const AboutPage()),
                ),
              ),
            ],
          ).entrance(context, index: 11),
          const SizedBox(height: FurFeelTokens.space7),
        ],
      ),
    );
  }
}

// ── Private helpers ───────────────────────────────────────────────────────────

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: FurFeelTokens.space4),
        child: Text(text, style: Theme.of(context).textTheme.labelSmall),
      );
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    this.iconColor,
    this.iconBackground,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color? iconColor;
  final Color? iconBackground;
  final String title;
  final String? subtitle;
  final bool value;
  final void Function(bool)? onChanged;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final dimmed = onChanged == null;
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: FurFeelTokens.space4, vertical: FurFeelTokens.space3),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: iconBackground ??
                  (dimmed ? FurFeelTokens.surfaceAlt : FurFeelTokens.brandSoft),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon,
                size: 18,
                color: iconColor ??
                    (dimmed ? FurFeelTokens.inkMuted : FurFeelTokens.brand)),
          ),
          const SizedBox(width: FurFeelTokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: tt.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: dimmed
                            ? FurFeelTokens.inkMuted
                            : FurFeelTokens.ink)),
                if (subtitle != null)
                  Text(subtitle!, style: tt.bodySmall),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: FurFeelTokens.space4, vertical: FurFeelTokens.space3),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: FurFeelTokens.brandSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: FurFeelTokens.brand),
            ),
            const SizedBox(width: FurFeelTokens.space3),
            Expanded(
              child: Text(label,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w500)),
            ),
            Text(value,
                style: TextStyle(
                    color: FurFeelTokens.brand,
                    fontWeight: FontWeight.w600)),
            const SizedBox(width: FurFeelTokens.space2),
            Icon(Icons.chevron_right, size: 20, color: FurFeelTokens.inkMuted),
          ],
        ),
      ),
    );
  }
}

class _UnitRow extends StatelessWidget {
  const _UnitRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final List<ButtonSegment<String>> segments;
  final String selected;
  final void Function(String) onChanged;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: FurFeelTokens.space4, vertical: FurFeelTokens.space3),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: FurFeelTokens.brandSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: FurFeelTokens.brand),
          ),
          const SizedBox(width: FurFeelTokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style:
                        tt.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                Text(subtitle, style: tt.bodySmall),
              ],
            ),
          ),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: segments,
            selected: {selected},
            onSelectionChanged: (sel) => onChanged(sel.first),
          ),
        ],
      ),
    );
  }
}
