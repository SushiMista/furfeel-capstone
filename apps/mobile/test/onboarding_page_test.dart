import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furfeel_mobile/pages/onboarding_page.dart';

void main() {
  testWidgets('walks through all three slides and finishes', (tester) async {
    var done = false;
    await tester.pumpWidget(
      MaterialApp(home: OnboardingPage(onDone: () => done = true)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Feel what they feel'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Stress, made simple'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Care as a team'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);
    expect(done, isFalse);

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    expect(done, isTrue);
  });

  testWidgets('skip finishes the intro immediately', (tester) async {
    var done = false;
    await tester.pumpWidget(
      MaterialApp(home: OnboardingPage(onDone: () => done = true)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(done, isTrue);
  });

  testWidgets('swiping updates the slide and the final CTA appears', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: OnboardingPage(onDone: () {})),
    );
    await tester.pumpAndSettle();

    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('Stress, made simple'), findsOneWidget);

    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('Get started'), findsOneWidget);
  });
}
