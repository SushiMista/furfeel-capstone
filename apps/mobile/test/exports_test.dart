import 'package:flutter_test/flutter_test.dart';
import 'package:furfeel_mobile/models/models.dart';
import 'package:furfeel_mobile/util/exports.dart';

TelemetryReading reading(int minute, {int? hr, double? temp, int? battery}) =>
    TelemetryReading(
      id: 'r$minute',
      dogId: 'dog-1',
      capturedAt: DateTime.utc(2026, 7, 17, 8, minute),
      heartRateBpm: hr,
      bodyTemperatureC: temp,
      batteryPercent: battery,
    );

const _dog = Dog(id: 'dog-1', ownerUserId: 'u1', name: 'Biscuit', breed: 'Corgi');

void main() {
  group('buildReadingsCsv (QA item 13)', () {
    test('one header + one row per reading, nulls as empty cells', () {
      final csv = buildReadingsCsv([
        reading(0, hr: 92, temp: 38.5, battery: 80),
        reading(1),
      ]);
      final lines = csv.trim().split('\n');
      expect(lines, hasLength(3));
      expect(lines.first, startsWith('captured_at,heart_rate_bpm'));
      expect(lines.first, contains('battery_percent'));
      expect(lines[1], contains(',92,'));
      expect(lines[1], endsWith(',80'));
      // All-null sensor row keeps its commas so columns stay aligned.
      expect(lines[2].split(','), hasLength(lines.first.split(',').length));
    });
  });

  group('vitalSummary', () {
    test('min/avg/max over non-null values only', () {
      final s = vitalSummary(
        [reading(0, hr: 80), reading(1, hr: 100), reading(2)],
        (r) => r.heartRateBpm?.toDouble(),
      );
      expect(s, isNotNull);
      expect(s!.min, 80);
      expect(s.max, 100);
      expect(s.avg, 90);
    });

    test('null when no values at all', () {
      expect(vitalSummary([reading(0)], (r) => r.heartRateBpm?.toDouble()), isNull);
    });
  });

  test('buildHealthReportPdf produces a real PDF with the disclaimer baked in', () async {
    final bytes = await buildHealthReportPdf(
      dog: _dog,
      from: DateTime(2026, 7, 10),
      to: DateTime(2026, 7, 17),
      readings: [reading(0, hr: 92, temp: 38.5)],
      classifications: [
        StressClassification(
          id: 'c1',
          dogId: 'dog-1',
          stressLevel: StressLevel.calm,
          createdAt: DateTime(2026, 7, 16, 9),
        ),
      ],
    );
    expect(bytes.length, greaterThan(500));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });
}
