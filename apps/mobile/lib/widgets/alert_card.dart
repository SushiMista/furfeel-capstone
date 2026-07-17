import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import '../theme/furfeel_tokens.dart';

/// Warm alert card (docs/19): coral accent for high severity, a clear
/// "Acknowledge" button while open; acknowledged alerts fade to muted.
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
    final isCritical = alert.severity == 'critical';
    final acknowledged = !alert.isOpen;

    return Opacity(
      opacity: acknowledged ? 0.6 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: FurFeelTokens.space3),
        padding: const EdgeInsets.all(FurFeelTokens.space4),
        decoration: BoxDecoration(
          color: isCritical && !acknowledged
              ? FurFeelTokens.statusHighBg
              : FurFeelTokens.surfaceAlt,
          borderRadius: BorderRadius.circular(FurFeelTokens.radiusMd),
          border: Border(
            left: BorderSide(
              width: 4,
              color: acknowledged
                  ? FurFeelTokens.hairline
                  : isCritical
                      ? FurFeelTokens.statusHighFg
                      : FurFeelTokens.accent,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              alert.message,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: FurFeelTokens.ink,
              ),
            ),
            const SizedBox(height: FurFeelTokens.space1),
            Text(
              '${_friendlyTime(alert.createdAt)}'
              '${acknowledged ? ' · ${alert.status}' : ''}',
              style: TextStyle(
                fontSize: FurFeelTokens.typeCaptionSize,
                color: FurFeelTokens.inkMuted,
              ),
            ),
            // Owner-delight pass: a simple "what you can do" per alert type,
            // right where the worry is. Observational + practical only.
            if (alert.isOpen && _tipFor(alert.type) != null) ...[
              const SizedBox(height: FurFeelTokens.space2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.tips_and_updates_outlined,
                      size: 16, color: FurFeelTokens.warm),
                  const SizedBox(width: FurFeelTokens.space2),
                  Expanded(
                    child: Text(
                      _tipFor(alert.type)!,
                      style: TextStyle(
                        fontSize: FurFeelTokens.typeCaptionSize,
                        color: FurFeelTokens.ink,
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
                    backgroundColor: FurFeelTokens.surface,
                    foregroundColor: FurFeelTokens.brandStrong,
                    minimumSize: const Size(0, FurFeelTokens.touchTargetMin),
                    padding: const EdgeInsets.symmetric(horizontal: FurFeelTokens.space4),
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
