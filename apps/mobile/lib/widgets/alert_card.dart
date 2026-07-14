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
