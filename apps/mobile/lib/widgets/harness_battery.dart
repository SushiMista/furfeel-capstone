import 'package:flutter/material.dart';
import '../models/models.dart';
import '../util/battery.dart';

/// Battery of the wearable harness, independent of canine stress classification.
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
    final color = available
        ? batteryColorFor(context, percent!)
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final reportedAt = fromReading ? reading?.capturedAt : null;
    return Tooltip(
      message: available
          ? 'Last reported${reportedAt != null ? ': ${reportedAt.toLocal()}' : ' battery value'}.${offline ? ' Harness is offline; this is not a live reading.' : ''}'
          : 'No valid battery reading has been received from this harness.',
      child: Semantics(
        label: label,
        excludeSemantics: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              available ? batteryIconFor(percent!) : Icons.battery_unknown,
              color: color,
              size: 18,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: low ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
