import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furfeel_mobile/models/models.dart';
import 'package:furfeel_mobile/widgets/stress_pill.dart';

void main() {
  test('each stress level has a distinct color and soft background', () {
    final fgs = StressLevel.values.map(stressLevelColor).toSet();
    final bgs = StressLevel.values.map(stressLevelSoftBg).toSet();
    expect(fgs.length, StressLevel.values.length);
    expect(bgs.length, StressLevel.values.length);
  });

  testWidgets('shows the capitalized word so meaning never rides on color alone',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: StressPill(level: StressLevel.high))),
    );
    expect(find.text('High'), findsOneWidget);
  });

  testWidgets('renders each level without overflow', (tester) async {
    for (final level in StressLevel.values) {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: StressPill(level: level, large: true))),
      );
      expect(tester.takeException(), isNull);
    }
  });
}
