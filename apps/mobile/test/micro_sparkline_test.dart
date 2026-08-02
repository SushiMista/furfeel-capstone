import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furfeel_mobile/widgets/micro_sparkline.dart';

Widget _host(Widget child) => MaterialApp(
      home: Scaffold(
        body: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );

void main() {
  group('MicroSparkline', () {
    testWidgets('draws nothing below two readings', (tester) async {
      for (final series in [<double>[], <double>[5]]) {
        await tester.pumpWidget(_host(
          MicroSparkline(series: series, color: const Color(0xFF2563EB)),
        ));
        final size = tester.getSize(find.byType(MicroSparkline));
        expect(size.height, 0, reason: 'series $series should collapse');
      }
    });

    testWidgets('draws one bar per reading once there are two', (tester) async {
      await tester.pumpWidget(_host(
        MicroSparkline(series: const [1, 2, 3, 4], color: const Color(0xFF2563EB)),
      ));
      expect(find.byType(Container), findsNWidgets(4));
    });

    testWidgets('a track draws a full-height capsule behind each bar',
        (tester) async {
      await tester.pumpWidget(_host(const MicroSparkline(
        series: [1, 2, 3],
        color: Color(0xFF2563EB),
        trackColor: Color(0xFFEAF1FE),
      )));
      // Track + value per column = two Containers each.
      expect(find.byType(Container), findsNWidgets(6));
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders day-initial captions beneath when labels match',
        (tester) async {
      await tester.pumpWidget(_host(const MicroSparkline(
        series: [1, 2, 3],
        color: Color(0xFF2563EB),
        labels: ['M', 'T', 'W'],
      )));
      for (final d in ['M', 'T', 'W']) {
        expect(find.text(d), findsOneWidget);
      }
    });

    testWidgets('a flat or all-zero series does not divide by zero',
        (tester) async {
      for (final series in [
        <double>[0, 0, 0],
        <double>[7, 7, 7],
      ]) {
        await tester.pumpWidget(_host(
          MicroSparkline(series: series, color: const Color(0xFF2563EB)),
        ));
        expect(tester.takeException(), isNull, reason: 'series $series threw');
        // Zero must still show as a bar: a missing bar reads as missing data,
        // which is a different claim from "the reading was zero".
        for (final c in tester.widgetList<Container>(find.byType(Container))) {
          expect(c.constraints?.maxHeight ?? 1, greaterThan(0));
        }
      }
    });
  });
}
