import 'package:flutter_test/flutter_test.dart';
import 'package:furfeel_mobile/pages/detailed_log_page.dart';

void main() {
  group('downsampleToSpots', () {
    test('returns every point untouched when the series already fits', () {
      final spots = downsampleToSpots([1, 2, 3], maxPoints: 96);
      expect(spots.length, 3);
      expect(spots.map((s) => s.y).toList(), [1, 2, 3]);
      // x stays the original reading index.
      expect(spots.map((s) => s.x).toList(), [0, 1, 2]);
    });

    test('caps a long series at maxPoints — the actual readability bug', () {
      // 24h of 10-second telemetry: what made the card a solid block of ink.
      final values = List<double?>.generate(8640, (i) => (i % 10).toDouble());
      final spots = downsampleToSpots(values, maxPoints: 96);
      expect(spots.length, lessThanOrEqualTo(96));
      expect(spots.length, greaterThan(1));
    });

    test('averages within each bucket rather than sampling one value', () {
      // Two buckets of two: [10, 20] -> 15, [30, 40] -> 35. A naive "take
      // every Nth point" would give 10 and 30 instead.
      final spots = downsampleToSpots([10, 20, 30, 40], maxPoints: 2);
      expect(spots.map((s) => s.y).toList(), [15, 35]);
    });

    test('skips nulls without inventing a zero', () {
      // docs/07: a missing field is stored null, never silently replaced —
      // a fake 0 would drag the line (and the average) down a cliff.
      final spots = downsampleToSpots([10, null, 20]);
      expect(spots.map((s) => s.y).toList(), [10, 20]);
      expect(spots.every((s) => s.y != 0), isTrue);
    });

    test('emits no spot for a bucket that is entirely null', () {
      final values = <double?>[null, null, 30, 40];
      final spots = downsampleToSpots(values, maxPoints: 2);
      expect(spots.length, 1);
      expect(spots.single.y, 35);
    });

    test('keeps x spanning the original index range so the axis still lines up', () {
      final values = List<double?>.generate(1000, (i) => i.toDouble());
      final spots = downsampleToSpots(values, maxPoints: 50);
      expect(spots.first.x, lessThan(20));
      expect(spots.last.x, greaterThan(980));
    });

    test('handles an empty series', () {
      expect(downsampleToSpots([]), isEmpty);
    });
  });

  group('axisTimeLabel', () {
    test('shows clock time within a single day', () {
      expect(axisTimeLabel(DateTime(2026, 7, 23, 16, 49), sameDay: true), '4:49 PM');
      expect(axisTimeLabel(DateTime(2026, 7, 23, 9, 5), sameDay: true), '9:05 AM');
    });

    test('renders midnight and noon as 12, not 0', () {
      expect(axisTimeLabel(DateTime(2026, 7, 23, 0, 30), sameDay: true), '12:30 AM');
      expect(axisTimeLabel(DateTime(2026, 7, 23, 12, 0), sameDay: true), '12:00 PM');
    });

    test('shows the date when the range spans more than one day', () {
      expect(axisTimeLabel(DateTime(2026, 7, 23, 16, 49), sameDay: false), 'Jul 23');
    });
  });
}
