import 'package:flutter_test/flutter_test.dart';
import 'package:furfeel_mobile/data/furfeel_repository.dart';
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

void main() {
  group('selectCareGuidance (docs/09: clinic row overrides the global default)', () {
    test('returns the global default when no clinic row matches', () {
      final result =
          selectCareGuidance([_globalMild, _globalHigh], StressLevel.mild, 'clinic-1');
      expect(result, _globalMild);
    });

    test('prefers the clinic-specific row over the global default', () {
      final result = selectCareGuidance(
          [_globalMild, _clinicMild, _globalHigh], StressLevel.mild, 'clinic-1');
      expect(result, _clinicMild);
    });

    test('ignores clinic rows for other clinics', () {
      final result = selectCareGuidance([_clinicMild], StressLevel.mild, 'clinic-2');
      expect(result, isNull);
    });

    test('falls back to global for home-only dogs (clinicId null)', () {
      final result =
          selectCareGuidance([_globalMild, _clinicMild], StressLevel.mild, null);
      expect(result, _globalMild);
    });

    test('returns null when no guidance exists for the level', () {
      expect(selectCareGuidance([_globalMild], StressLevel.high, null), isNull);
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
