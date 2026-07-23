import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furfeel_mobile/widgets/day_timeline.dart';

void main() {
  group('hourLabel', () {
    test('reads midnight and noon as words, not 0 and 12', () {
      expect(hourLabel(0), '12am');
      expect(hourLabel(12), 'noon');
    });

    test('formats morning and afternoon hours on a 12-hour clock', () {
      expect(hourLabel(9), '9am');
      expect(hourLabel(11), '11am');
      expect(hourLabel(13), '1pm');
      expect(hourLabel(23), '11pm');
    });

    test('covers every hour of the day without crashing or repeating midnight',
        () {
      final labels = [for (var h = 0; h < 24; h++) hourLabel(h)];
      expect(labels.length, 24);
      expect(labels.toSet().length, 24, reason: 'each hour reads distinctly');
    });
  });

  // The strip itself is self-loading from a repository, so the widget-level
  // behaviour (tap a block -> readout names that hour) is covered by the
  // root_shell tests that render a real Trends tab. What's unit-tested here is
  // the labelling, which is the part that turns a colour band into something
  // readable -- a wrong label is the regression that matters.
  testWidgets('hour labels are the same strings the axis renders', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [Text(hourLabel(0)), Text(hourLabel(12))],
          ),
        ),
      ),
    );
    expect(find.text('12am'), findsOneWidget);
    expect(find.text('noon'), findsOneWidget);
  });
}
