import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import '../theme/furfeel_tokens.dart';
import '../util/motion.dart';

/// Visual language for one alert severity: word + colors, never color alone
/// (docs/19). Shared by the card chip and the leading icon badge.
({String label, Color fg, Color bg}) alertSeverityStyle(BuildContext context, String severity) =>
    switch (severity) {
      'critical' => (
          label: 'Check soon',
          fg: context.ff.statusHighFg,
          bg: context.ff.statusHighBg,
        ),
      'warning' => (
          label: 'Heads up',
          fg: context.ff.statusModerateFg,
          bg: context.ff.statusModerateBg,
        ),
      _ => (
          label: 'Info',
          fg: context.ff.brand,
          bg: context.ff.brandSoft,
        ),
    };

/// Per-type glyph so an owner can tell a stress alert from harness chatter
/// at a glance, before reading a word.
IconData alertTypeIcon(String type) => switch (type) {
      'high_stress' => Icons.warning_amber_rounded,
      'moderate_stress' => Icons.mood_bad_outlined,
      'device_offline' => Icons.sensors_off_outlined,
      'low_battery' => Icons.battery_alert_outlined,
      _ => Icons.notifications_outlined,
    };

/// Short plain title per alert type; the stored message becomes small print.
/// Null for unknown types, where the message has to stand alone.
String? alertHeadline(String type) => switch (type) {
      'high_stress' => 'Stress level is high',
      'moderate_stress' => 'Stress level is up',
      'device_offline' => 'Device stopped sending data',
      'low_battery' => 'Battery is low',
      _ => null,
    };

/// Small print under [alertHeadline]. Offline messages keep their stored form
/// because the dashboard parses the device code out of them.
String alertDetails(BuildContext context, Alert alert) {
  final offline = RegExp(
    r'^Device (\S+) stopped sending data \(last seen \S+ (\d{2}):(\d{2})',
  ).firstMatch(alert.message);
  if (offline == null) return alert.message;
  final lastSeen = MaterialLocalizations.of(context).formatTimeOfDay(
    TimeOfDay(hour: int.parse(offline[2]!), minute: int.parse(offline[3]!)),
  );
  return '${offline[1]} · Last seen $lastSeen';
}

/// One alert as a single line of meaning (docs/19): type icon, short title,
/// and when. Tapping drops down the details and tip. Open alerts sit on a tinted
/// card with Got it in reach; past alerts are quiet list rows.
class AlertCard extends StatefulWidget {
  const AlertCard({super.key, required this.alert, this.onAcknowledge});

  final Alert alert;
  final Future<void> Function(Alert alert)? onAcknowledge;

  @override
  State<AlertCard> createState() => _AlertCardState();
}

class _AlertCardState extends State<AlertCard> {
  static const _iconSize = 32.0;

  bool _busy = false;
  bool _expanded = false;

  Future<void> _acknowledge() async {
    // Light haptic on Acknowledge (docs/19 §5a micro-interactions).
    HapticFeedback.lightImpact();
    setState(() => _busy = true);
    try {
      await widget.onAcknowledge!(widget.alert);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final alert = widget.alert;
    final open = alert.isOpen;
    final severity = alertSeverityStyle(context, alert.severity);
    final headline = alertHeadline(alert.type);
    final tip = open ? _tipFor(alert.type) : null;
    final when = _friendlyTime(context, alert.createdAt);
    final details = headline == null
        ? null
        : [
            if (!open) alert.status == 'acknowledged' ? 'Seen' : 'Resolved',
            alertDetails(context, alert),
          ].join(' · ');
    final canExpand = details != null || tip != null;
    final indent = _iconSize + FurFeelTokens.space3;
    final captionStyle = TextStyle(
      fontSize: FurFeelTokens.typeCaptionSize,
      color: context.ff.inkMuted,
    );

    final row = Row(
      children: [
        Container(
          width: _iconSize,
          height: _iconSize,
          decoration: BoxDecoration(
            color: open ? severity.bg : context.ff.surfaceAlt,
            shape: BoxShape.circle,
          ),
          child: Icon(
            alertTypeIcon(alert.type),
            size: 18,
            color: open ? severity.fg : context.ff.inkMuted,
          ),
        ),
        const SizedBox(width: FurFeelTokens.space3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                headline ?? alert.message,
                style: TextStyle(
                  fontWeight: open ? FontWeight.w700 : FontWeight.w500,
                  color: open ? context.ff.ink : context.ff.inkMuted,
                ),
              ),
              Text(open ? '${severity.label} · $when' : when, style: captionStyle),
            ],
          ),
        ),
        if (canExpand)
          AnimatedRotation(
            turns: _expanded ? 0.5 : 0,
            duration: FurFeelTokens.motionFast,
            child: Icon(Icons.expand_more, size: 20, color: context.ff.inkMuted),
          ),
      ],
    );

    final dropDownBody = !_expanded
        ? const SizedBox(width: double.infinity)
        : Padding(
            padding: EdgeInsets.only(left: indent, top: FurFeelTokens.space2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (details != null) Text(details, style: captionStyle),
                if (tip != null) ...[
                  const SizedBox(height: FurFeelTokens.space2),
                  Text(
                    tip,
                    style: TextStyle(
                      fontSize: FurFeelTokens.typeCaptionSize,
                      color: context.ff.ink,
                    ),
                  ),
                ],
              ],
            ),
          );
    // AnimatedSize throws on a zero duration, so reduced motion skips it.
    final dropDown = context.reduceMotion
        ? dropDownBody
        : AnimatedSize(
            duration: FurFeelTokens.motionFast,
            alignment: Alignment.topLeft,
            child: dropDownBody,
          );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: canExpand,
          expanded: canExpand ? _expanded : null,
          child: InkWell(
            onTap: canExpand
                ? () => setState(() => _expanded = !_expanded)
                : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [row, dropDown],
            ),
          ),
        ),
        if (open && widget.onAcknowledge != null)
          Padding(
            padding: EdgeInsets.only(left: indent, top: FurFeelTokens.space2),
            child: TextButton(
              onPressed: _busy ? null : _acknowledge,
              style: TextButton.styleFrom(
                backgroundColor: context.ff.surface,
                foregroundColor: context.ff.brandStrong,
                minimumSize: const Size(0, FurFeelTokens.touchTargetMin),
                padding: const EdgeInsets.symmetric(
                  horizontal: FurFeelTokens.space4,
                ),
                shape: const StadiumBorder(),
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
              child: Text(_busy ? 'Saving…' : 'Got it'),
            ),
          ),
      ],
    );

    return Material(
      type: MaterialType.transparency,
      child: Container(
        margin: open
            ? const EdgeInsets.only(bottom: FurFeelTokens.space2)
            : EdgeInsets.zero,
        padding: open
            ? const EdgeInsets.all(FurFeelTokens.space3)
            : const EdgeInsets.symmetric(vertical: FurFeelTokens.space3),
        decoration: open
            ? BoxDecoration(
                color: alert.severity == 'critical'
                    ? context.ff.statusHighBg
                    : context.ff.surfaceAlt,
                borderRadius: BorderRadius.circular(FurFeelTokens.radiusMd),
              )
            : BoxDecoration(
                border: Border(bottom: BorderSide(color: context.ff.hairline)),
              ),
        child: content,
      ),
    );
  }
}

/// Practical next step per alert type; null = the message says it all.
String? _tipFor(String type) => switch (type) {
      'moderate_stress' || 'high_stress' =>
        'A quiet, familiar spot and your company usually help — the Care '
            'Insights card on Home has a tip for right now.',
      'device_offline' =>
        "It can take a minute to reconnect once it's back in range.",
      'low_battery' => 'Pop the harness on the charger when you get a chance.',
      _ => null,
    };

String _friendlyTime(BuildContext context, DateTime time) {
  final now = DateTime.now();
  final diff = now.difference(time);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  final strings = MaterialLocalizations.of(context);
  final clock = strings.formatTimeOfDay(TimeOfDay.fromDateTime(time));
  final daysAgo =
      DateUtils.dateOnly(now).difference(DateUtils.dateOnly(time)).inDays;
  return switch (daysAgo) {
    0 => 'Today at $clock',
    1 => 'Yesterday at $clock',
    _ => '${strings.formatShortMonthDay(time)} at $clock',
  };
}
