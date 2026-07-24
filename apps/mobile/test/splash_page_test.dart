import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furfeel_mobile/pages/splash_page.dart';
import 'package:furfeel_mobile/theme/furfeel_theme.dart';
import 'package:furfeel_mobile/theme/furfeel_tokens.dart';

Widget app(Widget child, {bool reduceMotion = false, bool dark = false}) =>
    MaterialApp(
      theme: buildFurFeelTheme(dark: dark),
      builder: (context, inner) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: inner!,
      ),
      home: child,
    );

void main() {
  testWidgets('shows the FurFeel wordmark and tagline', (tester) async {
    await tester.pumpWidget(app(const SplashPage()));
    await tester.pumpAndSettle();

    // The wordmark is two-tone RichText ("Fur" + "Feel"), so match the
    // rendered string rather than a single Text widget.
    expect(find.textContaining('Fur', findRichText: true), findsWidgets);
    expect(find.text('Know how your dog is feeling'), findsOneWidget);
  });

  testWidgets('cold start shows no loader', (tester) async {
    await tester.pumpWidget(app(const SplashPage()));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // A launch that resolves in a few hundred ms should never flash a bar.
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  // Reduced motion so the logo's entrance doesn't leave flutter_animate
  // timers pending; the indeterminate bar never settles, so these can't use
  // pumpAndSettle either way.
  testWidgets('the loading variant holds its bar back, then shows it',
      (tester) async {
    await tester.pumpWidget(
      app(const SplashPage.loading(), reduceMotion: true),
    );

    // Not merely transparent — not built, so a fast load renders nothing.
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(LinearProgressIndicator), findsNothing);

    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('the wait before the loader applies under reduced motion too',
      (tester) async {
    await tester.pumpWidget(
      app(const SplashPage.loading(), reduceMotion: true),
    );
    await tester.pump(const Duration(milliseconds: 300));

    // The delay exists to avoid a flash, which is not a motion preference —
    // skipping it here would give reduced-motion users the worse behaviour.
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  // The native Android splash paints @color/splash_background (generated from
  // design_tokens.json). If this screen used any other colour the handoff
  // would flash, so it is pinned to the same token in both themes.
  testWidgets('background matches the native splash colour', (tester) async {
    for (final dark in [false, true]) {
      await tester.pumpWidget(app(const SplashPage(), dark: dark));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(SplashPage));
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, context.ff.bg);
    }
  });
}
