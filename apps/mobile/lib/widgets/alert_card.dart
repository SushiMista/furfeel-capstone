import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import '../theme/furfeel_tokens.dart';

/// Visual language for one alert severity: word + colors, never color alone
/// (docs/19). Shared by the card chip and the leading icon badge.
({String label, Color fg, Color bg}) alertSeverityStyle(BuildContext context, String severity) =>
    switch (severity) {
      'critical' => (
          label: 'Critical',
          fg: context.ff.statusHighFg,
          bg: context.ff.statusHighBg,
        ),
      'warning' => (
          label: 'Warning',
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

/// Warm alert card (docs/19): severity-tinted icon badge + severity chip,
/// the event time up front, a clear "Acknowledge" button while open;
/// acknowledged alerts fade to muted.
class AlertCard extends StatefulWidget {
  const AlertCard({super.key, required this.alert, this.onAcknowledge});

  final Alert alert;
  final Future<void> Function(Alert alert)? onAcknowledge;

  @override
  State<AlertCard> createState() => _AlertCardState();
}

class _AlertCardState extends State<AlertCard> {
  bool _busy = false;

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
    final acknowledged = !alert.isOpen;
    final severity = alertSeverityStyle(context, alert.severity);

    return Opacity(
      opacity: acknowledged ? 0.6 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: FurFeelTokens.space3),
        padding: const EdgeInsets.all(FurFeelTokens.space4),
        decoration: BoxDecoration(
          color: alert.severity == 'critical' && !acknowledged
              ? context.ff.statusHighBg
              : context.ff.surfaceAlt,
          borderRadius: BorderRadius.circular(FurFeelTokens.radiusMd),
          border: Border(
            left: BorderSide(
              width: 4,
              color: acknowledged ? context.ff.hairline : severity.fg,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Severity-tinted type icon: the visual aid that reads before
            // any text does.
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: acknowledged ? context.ff.surface : severity.bg,
                shape: BoxShape.circle,
              ),
              child: Icon(
                alertTypeIcon(alert.type),
                size: 20,
                color: acknowledged ? context.ff.inkMuted : severity.fg,
              ),
            ),
            const SizedBox(width: FurFeelTokens.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          _friendlyTime(alert.createdAt) +
                              (acknowledged ? ' · ${alert.status}' : ''),
                          style: TextStyle(
                            fontSize: FurFeelTokens.typeCaptionSize,
                            fontWeight: FontWeight.w600,
                            color: context.ff.inkMuted,
                          ),
                        ),
                      ),
                      // Severity chip — the alert's level as a word.
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: FurFeelTokens.space2,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: acknowledged ? context.ff.surface : severity.bg,
                          borderRadius:
                              BorderRadius.circular(FurFeelTokens.radiusPill),
                        ),
                        child: Text(
                          severity.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: acknowledged
                                ? context.ff.inkMuted
                                : severity.fg,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: FurFeelTokens.space1),
                  Text(
                    alert.message,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: context.ff.ink,
                    ),
                  ),
                  // Owner-delight pass: a simple "what you can do" per alert
                  // type, right where the worry is. Observational + practical.
                  if (alert.isOpen && _tipFor(alert.type) != null) ...[
                    const SizedBox(height: FurFeelTokens.space2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.tips_and_updates_outlined,
                            size: 16, color: context.ff.warm),
                        const SizedBox(width: FurFeelTokens.space2),
                        Expanded(
                          child: Text(
                            _tipFor(alert.type)!,
                            style: TextStyle(
                              fontSize: FurFeelTokens.typeCaptionSize,
                              color: context.ff.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (alert.isOpen && widget.onAcknowledge != null) ...[
                    const SizedBox(height: FurFeelTokens.space3),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: _busy ? null : _acknowledge,
                        style: TextButton.styleFrom(
                          backgroundColor: context.ff.surface,
                          foregroundColor: context.ff.brandStrong,
                          minimumSize: const Size(0, FurFeelTokens.touchTargetMin),
                          padding: const EdgeInsets.symmetric(
                              horizontal: FurFeelTokens.space4),
                          shape: const StadiumBorder(),
                          textStyle: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        child: Text(_busy ? 'Acknowledging…' : 'Acknowledge'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
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
        'Check the strap and Wi-Fi range, then give it a minute to reconnect.',
      'low_battery' => 'Pop the harness on the charger when you get a chance.',
      _ => null,
    };

String _friendlyTime(DateTime time) {
  final now = DateTime.now();
  final diff = now.difference(time);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24 && now.day == time.day) {
    return 'today at ${_hhmm(time)}';
  }
  return '${time.year}-${_pad(time.month)}-${_pad(time.day)} ${_hhmm(time)}';
}

String _hhmm(DateTime t) => '${_pad(t.hour)}:${_pad(t.minute)}';
String _pad(int n) => n.toString().padLeft(2, '0');
