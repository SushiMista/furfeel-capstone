import 'package:flutter_test/flutter_test.dart';
import 'package:furfeel_mobile/models/models.dart';

void main() {
  group('StressLevel', () {
    test('parses every level name', () {
      expect(StressLevel.fromName('calm'), StressLevel.calm);
      expect(StressLevel.fromName('mild'), StressLevel.mild);
      expect(StressLevel.fromName('moderate'), StressLevel.moderate);
      expect(StressLevel.fromName('high'), StressLevel.high);
    });

    test('falls back to calm for unknown values instead of throwing', () {
      expect(StressLevel.fromName('bogus'), StressLevel.calm);
    });

    test('phrases are encouraging and mention the dog', () {
      expect(StressLevel.calm.phrase('Biscuit'), 'Biscuit is calm right now');
      expect(StressLevel.high.phrase('Biscuit'), contains('Biscuit'));
    });
  });

  group('TelemetryReading.fromMap', () {
    test('parses a full row, tolerating int/double variance from JSON', () {
      final reading = TelemetryReading.fromMap({
        'id': 'r1',
        'dog_id': 'd1',
        'captured_at': '2026-07-11T08:00:00Z',
        'heart_rate_bpm': 92,
        'body_temperature_c': 38, // integer from JSON, must not throw
        'respiratory_rate_bpm': 22.0, // double from JSON, must not throw
        'motion_activity': 0.3,
        'posture': 'standing',
      });
      expect(reading.heartRateBpm, 92);
      expect(reading.bodyTemperatureC, 38.0);
      expect(reading.respiratoryRateBpm, 22);
      expect(reading.capturedAt.isUtc, isFalse); // converted to local time
    });

    test('parses nulls for missing sensor fields', () {
      final reading = TelemetryReading.fromMap({
        'id': 'r1',
        'dog_id': 'd1',
        'captured_at': '2026-07-11T08:00:00Z',
      });
      expect(reading.heartRateBpm, isNull);
      expect(reading.bodyTemperatureC, isNull);
    });
  });

  group('Alert.fromMap', () {
    test('parses an open alert', () {
      final alert = Alert.fromMap({
        'id': 'a1',
        'dog_id': 'd1',
        'severity': 'critical',
        'type': 'high_stress',
        'message': 'Biscuit is showing high stress',
        'status': 'open',
        'acknowledged_by': null,
        'acknowledged_at': null,
        'created_at': '2026-07-11T08:00:00Z',
      });
      expect(alert.isOpen, isTrue);
      expect(alert.acknowledgedAt, isNull);
    });

    test('parses an acknowledged alert', () {
      final alert = Alert.fromMap({
        'id': 'a1',
        'dog_id': 'd1',
        'severity': 'warning',
        'type': 'moderate_stress',
        'message': 'msg',
        'status': 'acknowledged',
        'acknowledged_by': 'u1',
        'acknowledged_at': '2026-07-11T09:00:00Z',
        'created_at': '2026-07-11T08:00:00Z',
      });
      expect(alert.isOpen, isFalse);
      expect(alert.acknowledgedAt, isNotNull);
    });
  });

  group('StressClassification.fromMap', () {
    test('parses a row', () {
      final c = StressClassification.fromMap({
        'id': 'c1',
        'dog_id': 'd1',
        'stress_level': 'moderate',
        'score': 5,
        'model_version': 'rule-v1',
        'created_at': '2026-07-11T08:00:00Z',
      });
      expect(c.stressLevel, StressLevel.moderate);
      expect(c.score, 5.0);
      expect(c.modelVersion, 'rule-v1');
    });
  });
}
