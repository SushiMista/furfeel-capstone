import 'package:flutter_test/flutter_test.dart';
import 'package:furfeel_mobile/insights/biometrics.dart';
import 'package:furfeel_mobile/models/models.dart';

TelemetryReading reading({
  int? hr,
  int? rr,
  double? temp,
  double? motion,
  double? ambient,
  double? humidity,
}) =>
    TelemetryReading(
      id: 'r1',
      dogId: 'dog-1',
      capturedAt: DateTime(2026, 7, 17, 8),
      heartRateBpm: hr,
      respiratoryRateBpm: rr,
      bodyTemperatureC: temp,
      motionActivity: motion,
      ambientTemperatureC: ambient,
      humidityPercent: humidity,
    );

void main() {
  group('heartRateStatus (QA item 10)', () {
    test('uses the global 90 bpm baseline when the clinic set none', () {
      expect(heartRateStatus(92, null), VitalStatus.normal);
      expect(heartRateStatus(110, null), VitalStatus.elevated); // ratio 1.22
      expect(heartRateStatus(150, null), VitalStatus.high); // ratio 1.67
      expect(heartRateStatus(55, null), VitalStatus.low); // ratio 0.61
      expect(heartRateStatus(null, null), isNull);
    });

    test("the dog's own baseline changes the verdict for the same number", () {
      const bigDog = DogBaseline(restingHeartRateBpm: 140);
      // 150 bpm is High against the global default but Normal for this dog
      // (ratio 1.07).
      expect(heartRateStatus(150, null), VitalStatus.high);
      expect(heartRateStatus(150, bigDog), VitalStatus.normal);
    });
  });

  group('respiratoryStatus', () {
    test('bands align with the rule-v1 1.3 / 1.8 tiers', () {
      expect(respiratoryStatus(24, null), VitalStatus.normal);
      expect(respiratoryStatus(35, null), VitalStatus.elevated); // 1.46
      expect(respiratoryStatus(46, null), VitalStatus.high); // 1.92 = panting
      expect(respiratoryStatus(10, null), VitalStatus.low);
    });
  });

  group('temperatureStatus', () {
    test('absolute bands match the vital detail typical range', () {
      expect(temperatureStatus(38.5), VitalStatus.normal);
      expect(temperatureStatus(39.4), VitalStatus.elevated);
      expect(temperatureStatus(39.9), VitalStatus.high);
      expect(temperatureStatus(37.0), VitalStatus.low);
      expect(temperatureStatus(null), isNull);
    });
  });

  test('vitalStatusPhrase reads like a sentence about this dog', () {
    expect(
      vitalStatusPhrase('Heart rate', '92 bpm', VitalStatus.normal, 'Biscuit'),
      'Heart rate 92 bpm — Normal for Biscuit',
    );
  });

  group('careContextKey (QA item 11 combination selection)', () {
    test('cold + stressed picks the warm-bed combination', () {
      expect(
        careContextKey(
          level: StressLevel.moderate,
          reading: reading(ambient: 4.0),
        ),
        'cold_stressed',
      );
    });

    test('hot + stressed picks the cool-down combination', () {
      expect(
        careContextKey(level: StressLevel.mild, reading: reading(ambient: 34.0)),
        'hot_stressed',
      );
    });

    test('panting in the heat outranks plain hot_stressed', () {
      expect(
        careContextKey(
          level: StressLevel.moderate,
          reading: reading(rr: 48, ambient: 34.0),
        ),
        'panting_hot',
      );
    });

    test('restless + elevated heart rate picks wind-down guidance', () {
      expect(
        careContextKey(
          level: StressLevel.mild,
          reading: reading(hr: 120, motion: 0.7, ambient: 24.0),
        ),
        'restless_high_hr',
      );
    });

    test('calm dog in cold/hot weather gets the comfort tip', () {
      expect(
        careContextKey(level: StressLevel.calm, reading: reading(ambient: 5.0)),
        'cold_calm',
      );
      expect(
        careContextKey(level: StressLevel.calm, reading: reading(ambient: 35.0)),
        'hot_calm',
      );
    });

    test('mild weather + settled dog has no combination (per-level fallback)', () {
      expect(
        careContextKey(
          level: StressLevel.calm,
          reading: reading(hr: 90, motion: 0.2, ambient: 24.0),
        ),
        isNull,
      );
      expect(careContextKey(level: StressLevel.calm, reading: null), isNull);
    });
  });
}
