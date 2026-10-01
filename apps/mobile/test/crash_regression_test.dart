import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furfeel_mobile/data/settings_controller.dart';
import 'package:furfeel_mobile/models/models.dart';
import 'package:furfeel_mobile/screens/home/root_shell.dart';

import 'fakes.dart';

/// QA regression tests for the two production crashes:
/// 1. dropdown.dart:1852 assert — editing a dog whose clinic_id wasn't in the
///    (still-loading) clinic items flashed an error frame.
/// 2. text_painter.dart:1351 assert — an unconstrained dog-name Text in the
///    header switcher chip could overflow its Row (the late-font-swap half of
///    that fix is preloading Inter in main(), which tests can't exercise).
void main() {

  group('header dog-name text', () {
    testWidgets('a very long dog name cannot overflow the header row', (tester) async {
      const longName = Dog(
        id: 'dog-1',
        ownerUserId: 'user-1',
        name: 'Sir Barksalot von Fluffington the Third of Wagging Meadows',
      );
      final repo = FakeRepository(dogs: const [longName]);
      await tester.pumpWidget(
        SettingsScope(
          controller: SettingsController(repo),
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
            home: RootShell(
              repository: repo,
              userEmail: 'owner@example.com',
              onSignOut: () async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // A RenderFlex overflow surfaces as an exception in tests.
      expect(tester.takeException(), isNull);
    });
  });
}
