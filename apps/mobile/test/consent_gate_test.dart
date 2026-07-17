import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furfeel_mobile/data/settings_controller.dart';
import 'package:furfeel_mobile/models/models.dart';
import 'package:furfeel_mobile/pages/consent_page.dart';
import 'package:furfeel_mobile/pages/root_shell.dart';

import 'fakes.dart';

const _dog = Dog(id: 'dog-1', ownerUserId: 'user-1', name: 'Biscuit');

Widget app(FakeRepository repo) => SettingsScope(
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
    );

void main() {
  testWidgets('no consent: monitoring is blocked behind the consent screen',
      (tester) async {
    final repo = FakeRepository(dogs: const [_dog])..consentAccepted = false;
    await tester.pumpWidget(app(repo));
    await tester.pumpAndSettle();

    expect(find.text('Before we start monitoring'), findsOneWidget);
    // No telemetry UI leaks past the gate.
    expect(find.text('Biscuit'), findsNothing);
    expect(repo.subscribeCalls, 0);
  });

  testWidgets('accepting records the current policy version and unlocks the app',
      (tester) async {
    final repo = FakeRepository(dogs: const [_dog])..consentAccepted = false;
    await tester.pumpWidget(app(repo));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('I agree — start monitoring'), 100,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('I agree — start monitoring'));
    await tester.pumpAndSettle();

    expect(repo.acceptedConsentVersions, [kConsentPolicyVersion]);
    expect(find.text('Before we start monitoring'), findsNothing);
    expect(find.text('Biscuit'), findsWidgets);
  });

  testWidgets('already-consented users go straight in', (tester) async {
    final repo = FakeRepository(dogs: const [_dog]); // consentAccepted = true
    await tester.pumpWidget(app(repo));
    await tester.pumpAndSettle();

    expect(find.text('Before we start monitoring'), findsNothing);
    expect(find.text('Biscuit'), findsWidgets);
  });
}
