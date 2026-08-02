import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furfeel_mobile/models/models.dart';
import 'package:furfeel_mobile/widgets/stress_pill.dart';
import 'package:furfeel_mobile/widgets/vital_stat_card.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('shows the number, its unit, and a plain-language descriptor',
      (tester) async {
    await tester.pumpWidget(_host(const VitalStatCard(
      label: 'Heart rate',
      icon: Icons.favorite_outline,
      value: '72',
      unit: 'bpm',
      descriptor: 'Resting',
    )));

    expect(find.text('Heart rate'), findsOneWidget);
    expect(find.text('72'), findsOneWidget);
    expect(find.text('bpm'), findsOneWidget);
    // A number the owner cannot interpret is not decision support.
    expect(find.text('Resting'), findsOneWidget);
  });

  testWidgets('omits the sparkline below two readings rather than drawing an empty frame',
      (tester) async {
    for (final series in [<double>[], <double>[3]]) {
      await tester.pumpWidget(_host(VitalStatCard(
        label: 'Stress level',
        icon: Icons.monitor_heart_outlined,
        value: '1.4',
        series: series,
      )));
      expect(find.byType(Container), findsWidgets);
      expect(tester.takeException(), isNull);
    }

    // Two readings is the floor where a trend becomes meaningful.
    await tester.pumpWidget(_host(const VitalStatCard(
      label: 'Stress level',
      icon: Icons.monitor_heart_outlined,
      value: '1.4',
      series: [1, 3],
    )));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a flat or all-zero series does not divide by zero', (tester) async {
    for (final series in [
      <double>[0, 0, 0, 0, 0, 0, 0],
      <double>[5, 5, 5, 5, 5, 5, 5],
    ]) {
      await tester.pumpWidget(_host(VitalStatCard(
        label: 'Stress level',
        icon: Icons.monitor_heart_outlined,
        value: '0.0',
        series: series,
      )));
      expect(tester.takeException(), isNull, reason: 'series $series threw');
    }
  });

  testWidgets('renders every stress level without overflow', (tester) async {
    for (final level in StressLevel.values) {
      await tester.pumpWidget(_host(VitalStatCard(
        label: 'Stress level',
        icon: Icons.monitor_heart_outlined,
        value: '1.4',
        unit: 'pts',
        descriptor: 'Mostly calm',
        level: level,
        series: const [1, 2, 4, 5, 2, 1, 2],
      )));
      expect(tester.takeException(), isNull, reason: 'level $level threw');
    }
  });

  testWidgets('chart fills are the mid stops, distinct from the text stops',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final context = tester.element(find.byType(SizedBox));

    // Every level has its own fill...
    final fills = StressLevel.values.map((l) => stressLevelChartFill(context, l)).toSet();
    expect(fills.length, StressLevel.values.length);

    // ...and a fill is never the text colour, which is the whole reason the
    // third stop exists (3:1 graphical vs 4.5:1 text — ADR-021).
    for (final level in StressLevel.values) {
      expect(
        stressLevelChartFill(context, level),
        isNot(stressLevelColor(context, level)),
        reason: '$level fill collapsed onto its text colour',
      );
    }
  });

  testWidgets('taps are exposed as a button to screen readers', (tester) async {
    final semanticsHandle = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(_host(VitalStatCard(
      label: 'Stress level',
      icon: Icons.monitor_heart_outlined,
      value: '1.4',
      descriptor: 'Mostly calm',
      onTap: () => taps++,
    )));

    await tester.tap(find.byType(InkWell));
    expect(taps, 1);

    final semantics = tester.getSemantics(find.byType(VitalStatCard));
    expect(semantics.label, contains('Stress level'));
    expect(semantics.label, contains('Mostly calm'));

    // The card excludes its descendants' semantics, so the tap action has to
    // be re-declared on the wrapper — assert it survived, or an assistive-tech
    // user gets a button that does nothing.
    expect(semantics.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

    semanticsHandle.dispose();
  });

  testWidgets('a card without onTap is not announced as a button', (tester) async {
    await tester.pumpWidget(_host(const VitalStatCard(
      label: 'Heart rate',
      icon: Icons.favorite_outline,
      value: '72',
    )));
    expect(find.byType(InkWell), findsNothing);
  });
}
