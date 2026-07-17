import 'package:flutter_test/flutter_test.dart';
import 'package:furfeel_mobile/insights/biometrics.dart';
import 'package:furfeel_mobile/models/models.dart';

const _globalMild = CareGuidance(
  stressLevel: StressLevel.mild,
  title: 'Global mild',
  body: 'global',
);
const _clinicMild = CareGuidance(
  stressLevel: StressLevel.mild,
  title: 'Clinic mild',
  body: 'clinic',
  clinicId: 'clinic-1',
);
const _globalHigh = CareGuidance(
  stressLevel: StressLevel.high,
  title: 'Global high',
  body: 'global',
);
const _coldStressed = CareGuidance(
  contextKey: 'cold_stressed',
  title: 'Warm and settle',
  body: 'Offer a warm bed',
);
const _clinicColdStressed = CareGuidance(
  contextKey: 'cold_stressed',
  title: 'Clinic warm tip',
  body: 'clinic',
  clinicId: 'clinic-1',
);

void main() {
  group('selectGuidance per-level (docs/09: clinic row overrides global)', () {
    test('returns the global default when no clinic row matches', () {
      final result = selectGuidance([_globalMild, _globalHigh],
          level: StressLevel.mild, contextKey: null, clinicId: 'clinic-1');
      expect(result, _globalMild);
    });

    test('prefers the clinic-specific row over the global default', () {
      final result = selectGuidance([_globalMild, _clinicMild, _globalHigh],
          level: StressLevel.mild, contextKey: null, clinicId: 'clinic-1');
      expect(result, _clinicMild);
    });

    test('ignores clinic rows for other clinics', () {
      final result = selectGuidance([_clinicMild],
          level: StressLevel.mild, contextKey: null, clinicId: 'clinic-2');
      expect(result, isNull);
    });

    test('falls back to global for home-only dogs (clinicId null)', () {
      final result = selectGuidance([_globalMild, _clinicMild],
          level: StressLevel.mild, contextKey: null, clinicId: null);
      expect(result, _globalMild);
    });

    test('returns null when no guidance exists for the level', () {
      expect(
          selectGuidance([_globalMild],
              level: StressLevel.high, contextKey: null, clinicId: null),
          isNull);
    });
  });

  group('selectGuidance combinations (QA item 11)', () {
    test('a matching context row beats the per-level default', () {
      final result = selectGuidance([_globalMild, _coldStressed],
          level: StressLevel.mild, contextKey: 'cold_stressed', clinicId: null);
      expect(result, _coldStressed);
    });

    test('clinic context row beats the global context row', () {
      final result = selectGuidance(
          [_globalMild, _coldStressed, _clinicColdStressed],
          level: StressLevel.mild,
          contextKey: 'cold_stressed',
          clinicId: 'clinic-1');
      expect(result, _clinicColdStressed);
    });

    test('falls back to per-level guidance when the context has no row', () {
      final result = selectGuidance([_globalMild],
          level: StressLevel.mild, contextKey: 'hot_stressed', clinicId: null);
      expect(result, _globalMild);
    });
  });

  group('Dog.ageYears', () {
    test('computes whole years from the birthdate', () {
      final threeYearsAgo = DateTime.now().subtract(const Duration(days: 3 * 365 + 30));
      final dog = Dog(
        id: 'd',
        ownerUserId: 'u',
        name: 'Biscuit',
        birthdate:
            '${threeYearsAgo.year}-${threeYearsAgo.month.toString().padLeft(2, '0')}-${threeYearsAgo.day.toString().padLeft(2, '0')}',
      );
      expect(dog.ageYears, 3);
    });

    test('is null without a parsable birthdate', () {
      const noBirthdate = Dog(id: 'd', ownerUserId: 'u', name: 'B');
      const junk = Dog(id: 'd', ownerUserId: 'u', name: 'B', birthdate: 'puppyhood');
      expect(noBirthdate.ageYears, isNull);
      expect(junk.ageYears, isNull);
    });
  });
}
