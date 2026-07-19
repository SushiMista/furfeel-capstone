import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/settings_controller.dart';
import '../models/models.dart';
import '../theme/furfeel_tokens.dart';
import '../util/motion.dart';
import '../widgets/alert_card.dart';

/// In-app alert list with acknowledge (docs/04 Notifications). QA: alerts are
/// grouped into type tabs (All / Stress / Harness), and each type has its own
/// notification toggle — mute the harness chatter, keep the stress alerts.
/// Muted types persist in user_settings.muted_alert_types.
class AlertsTab extends StatefulWidget {
  const AlertsTab({
    super.key,
    required this.dog,
    required this.alerts,
    required this.onAcknowledge,
    required this.onRefresh,
  });

  final Dog dog;
  final List<Alert> alerts;
  final Future<void> Function(Alert alert) onAcknowledge;
  final Future<void> Function() onRefresh;

  @override
  State<AlertsTab> createState() => _AlertsTabState();
}

/// Alert `type` groups shown as tabs. Stress covers both alerting levels;
/// Harness is device health (connectivity + battery).
enum _AlertGroup {
  all('All', null),
  stress('Stress', ['moderate_stress', 'high_stress']),
  harness('Harness', ['device_offline', 'low_battery']);

  const _AlertGroup(this.label, this.types);

  final String label;
  final List<String>? types;

  bool matches(Alert alert) => types == null || types!.contains(alert.type);
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _dayLabel(DateTime t) {
  final now = DateTime.now();
  if (_sameDay(t, now)) return 'TODAY';
  if (_sameDay(t, now.subtract(const Duration(days: 1)))) return 'YESTERDAY';
  const months = [
    'JANUARY', 'FEBRUARY', 'MARCH', 'APRIL', 'MAY', 'JUNE',
    'JULY', 'AUGUST', 'SEPTEMBER', 'OCTOBER', 'NOVEMBER', 'DECEMBER',
  ];
  return '${months[t.month - 1]} ${t.day}, ${t.year}';
}

class _AlertsTabState extends State<AlertsTab> {
  _AlertGroup _group = _AlertGroup.all;

  @override
  Widget build(BuildContext context) {
    final controller = SettingsScope.of(context);
    final settings = controller.settings;
    final visible = widget.alerts.where(_group.matches).toList();
    final groupTypes = _group.types;
    final muted =
        groupTypes != null && groupTypes.every(settings.mutedAlertTypes.contains);

    void toggleMute() {
      if (groupTypes == null) return;
      HapticFeedback.selectionClick();
      final next = muted
          ? settings.mutedAlertTypes.where((t) => !groupTypes.contains(t)).toList()
          : {...settings.mutedAlertTypes, ...groupTypes}.toList();
      controller.update(settings.copyWith(mutedAlertTypes: next));
    }

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(FurFeelTokens.space4),
        children: [
          SegmentedButton<_AlertGroup>(
            segments: [
              for (final group in _AlertGroup.values)
                ButtonSegment(
                  value: group,
                  label: Text(group.label),
                  icon: settings.mutedAlertTypes.isNotEmpty &&
                          group.types != null &&
                          group.types!.every(settings.mutedAlertTypes.contains)
                      ? const Icon(Icons.notifications_off_outlined, size: 16)
                      : null,
                ),
            ],
            selected: {_group},
            onSelectionChanged: (selection) =>
                setState(() => _group = selection.first),
          ),
          const SizedBox(height: FurFeelTokens.space3),
          // Messenger-style per-type notification control for the open tab.
          if (groupTypes != null)
            Material(
              color: context.ff.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(FurFeelTokens.radiusMd),
                side: BorderSide(color: context.ff.hairline),
              ),
              child: SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: FurFeelTokens.space4,
                ),
                title: Text(
                  'Notify me about ${_group.label.toLowerCase()} alerts',
                  style: TextStyle(
                    fontSize: FurFeelTokens.typeBodyMobileSize,
                    fontWeight: FontWeight.w600,
                    color: context.ff.ink,
                  ),
                ),
                subtitle: Text(
                  muted
                      ? 'Muted — they still appear here, just no push.'
                      : 'Push notifications are on for this type.',
                  style: TextStyle(
                    fontSize: FurFeelTokens.typeCaptionSize,
                    color: context.ff.inkMuted,
                  ),
                ),
                value: !muted,
                onChanged: settings.notificationsEnabled ? (_) => toggleMute() : null,
              ),
            ).entrance(context),
          const SizedBox(height: FurFeelTokens.space3),
          if (visible.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(FurFeelTokens.space5),
              decoration: BoxDecoration(
                color: context.ff.surfaceAlt,
                borderRadius: BorderRadius.circular(FurFeelTokens.radiusMd),
              ),
              child: Text(
                _group == _AlertGroup.all
                    ? 'No alerts — ${widget.dog.name} is doing great'
                    : 'No ${_group.label.toLowerCase()} alerts — all clear',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.ff.inkMuted),
              ),
            ).entrance(context, index: 1)
          else
            // "When did this happen?" first: alerts grouped under a date
            // header (Today / Yesterday / full date), newest group on top.
            for (final (i, alert) in visible.indexed) ...[
              if (i == 0 ||
                  !_sameDay(alert.createdAt, visible[i - 1].createdAt))
                Padding(
                  padding: EdgeInsets.only(
                    top: i == 0 ? 0 : FurFeelTokens.space3,
                    bottom: FurFeelTokens.space2,
                  ),
                  child: Text(
                    _dayLabel(alert.createdAt),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              AlertCard(alert: alert, onAcknowledge: widget.onAcknowledge)
                  .entrance(context, index: 1 + i),
            ],
        ],
      ),
    );
  }
}
