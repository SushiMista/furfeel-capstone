import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furfeel_mobile/theme/furfeel_theme.dart';

Widget _app({required bool reduceMotion}) => MaterialApp(
      theme: buildFurFeelTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(body: Text('Second page')),
                ),
              ),
              child: const Text('Push'),
            ),
          ),
        ),
      ),
    );

double _minOpacityAncestorOf(WidgetTester tester, Finder of) {
  final fades = tester.widgetList<FadeTransition>(
      find.ancestor(of: of, matching: find.byType(FadeTransition)));
  return fades.map((f) => f.opacity.value).reduce((a, b) => a < b ? a : b);
}

void main() {
  testWidgets('page push fades through instead of using the default platform transition',
      (tester) async {
    await tester.pumpWidget(_app(reduceMotion: false));
    await tester.tap(find.text('Push'));
    // Two frames to get the new route mounted, no elapsed time yet — the
    // incoming page should still be essentially invisible this early.
    await tester.pump();
    await tester.pump();
    expect(_minOpacityAncestorOf(tester, find.text('Second page')), lessThan(0.1));

    // Partway through the 300ms default duration: still mid-fade.
    await tester.pump(const Duration(milliseconds: 150));
    final mid = _minOpacityAncestorOf(tester, find.text('Second page'));
    expect(mid, greaterThan(0));
    expect(mid, lessThan(1));

    await tester.pumpAndSettle();
    expect(_minOpacityAncestorOf(tester, find.text('Second page')), 1);
  });

  testWidgets('reduced motion collapses the push to an instant swap', (tester) async {
    await tester.pumpWidget(_app(reduceMotion: true));
    await tester.tap(find.text('Push'));
    // Same two frames just to get the route mounted — no time-based
    // animation pumps needed, unlike the case above.
    await tester.pump();
    await tester.pump();

    expect(find.text('Second page'), findsOneWidget);
    expect(find.byType(FadeTransition), findsNothing);
  });
}
