import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/furfeel_tokens.dart';
import '../util/battery.dart';
import 'curved_status_header.dart';

/// Battery of the wearable harness, independent of canine stress classification.
///
/// A translucent pill matching `StressPill(onDark: true)`, for use over photos
/// and the status hero. Low and offline ride on icons to fit the card's top row;
/// the spoken label and tooltip keep the full wording.
class HarnessBattery extends StatelessWidget {
  const HarnessBattery({super.key, this.device, this.reading});
  final Device? device;
  final TelemetryReading? reading;
  @override
  Widget build(BuildContext context) {
    bool valid(int? n) => n != null && n >= 0 && n <= 100;
    final fromReading = valid(reading?.batteryPercent);
    final percent = fromReading
        ? reading!.batteryPercent
        : device?.batteryPercent;
    final available = valid(percent);
    final low = available && percent! <= 15;
    final offline = device?.status == 'offline';
    final label =
        'Harness battery: ${available ? '${percent!}%${low ? ' · Low' : ''}' : 'Unavailable'}${offline ? ' · Offline' : ''}';
    final reportedAt = fromReading ? reading?.capturedAt : null;
    return Tooltip(
      message: available
          ? 'Last reported${reportedAt != null ? ': ${reportedAt.toLocal()}' : ' battery value'}.${offline ? ' Harness is offline; this is not a live reading.' : ''}'
          : 'No valid battery reading has been received from this harness.',
      child: Semantics(
        label: label,
        excludeSemantics: true,
        child: GlassPill(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                available ? batteryIconFor(percent!) : Icons.battery_unknown,
                color: Colors.white,
                size: 14,
              ),
              const SizedBox(width: 2),
              Text(
                available ? '${percent!}%' : '--',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: FurFeelTokens.typeLabelSize,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (offline) ...[
                const SizedBox(width: 3),
                const Icon(Icons.wifi_off, color: Colors.white, size: 13),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
