import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furfeel_mobile/theme/furfeel_theme.dart';
import 'package:furfeel_mobile/theme/furfeel_tokens.dart';

void main() {
  // testWidgets, not test: buildFurFeelTheme touches google_fonts, which needs
  // the test binding to stub font fetching.
  testWidgets('light and dark themes carry their FurFeelPalette extension',
      (tester) async {
    expect(buildFurFeelTheme().extension<FurFeelPalette>(), FurFeelPalette.light);
    expect(buildFurFeelTheme(dark: true).extension<FurFeelPalette>(),
        FurFeelPalette.dark);
  });

  testWidgets('context.ff resolves the ambient theme, light fallback without one',
      (tester) async {
    late Color inTheme;
    late Color bare;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFurFeelTheme(dark: true),
        home: Builder(builder: (context) {
          inTheme = context.ff.bg;
          return const SizedBox();
        }),
      ),
    );
    await tester.pumpWidget(Builder(builder: (context) {
      bare = context.ff.bg;
      return const SizedBox();
    }));
    expect(inTheme, FurFeelPalette.dark.bg);
    expect(bare, FurFeelPalette.light.bg);
  });
}
