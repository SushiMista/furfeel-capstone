import 'package:flutter_test/flutter_test.dart';
import 'package:furfeel_mobile/util/friendly_time.dart';

void main() {
  group('clockTime', () {
    test('formats midnight, noon, morning, and afternoon in 12-hour time', () {
      expect(clockTime(DateTime(2026, 7, 11, 0, 5)), '12:05 AM');
      expect(clockTime(DateTime(2026, 7, 11, 9, 7)), '9:07 AM');
      expect(clockTime(DateTime(2026, 7, 11, 12, 0)), '12:00 PM');
      expect(clockTime(DateTime(2026, 7, 11, 15, 42)), '3:42 PM');
    });
  });
}
