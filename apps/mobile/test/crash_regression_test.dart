import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furfeel_mobile/data/settings_controller.dart';
import 'package:furfeel_mobile/models/models.dart';
import 'package:furfeel_mobile/pages/dog_form_page.dart';
import 'package:furfeel_mobile/pages/root_shell.dart';

import 'fakes.dart';

/// QA regression tests for the two production crashes:
/// 1. dropdown.dart:1852 assert — editing a dog whose clinic_id wasn't in the
///    (still-loading) clinic items flashed an error frame.
/// 2. text_painter.dart:1351 assert — an unconstrained dog-name Text in the
///    header switcher chip could overflow its Row (the late-font-swap half of
///    that fix is preloading Inter in main(), which tests can't exercise).
void main() {
  group('edit-dog dropdown', () {
    testWidgets('editing a dog with a clinic set crashes no frame while clinics load',
        (tester) async {
      const dog = Dog(
        id: 'dog-1',
        ownerUserId: 'user-1',
        name: 'Biscuit',
        clinicId: 'clinic-1',
      );
      final repo = FakeRepository(
        dogs: const [dog],
        clinics: const [Clinic(id: 'clinic-1', name: 'Sunrise Veterinary Clinic')],
      );
      await tester.pumpWidget(
        MaterialApp(home: DogFormPage(repository: repo, dog: dog)),
      );
      // First frame renders before fetchClinics resolves — this frame threw.
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // Once loaded, the real clinic name is selected and shown on the button.
      await tester.scrollUntilVisible(find.text('Sunrise Veterinary Clinic'), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('Sunrise Veterinary Clinic'), findsOneWidget);
    });

    testWidgets('duplicate clinics from the backend are deduped', (tester) async {
      const dog = Dog(
        id: 'dog-1',
        ownerUserId: 'user-1',
        name: 'Biscuit',
        clinicId: 'clinic-1',
      );
      final repo = FakeRepository(
        dogs: const [dog],
        clinics: const [
          Clinic(id: 'clinic-1', name: 'Sunrise Veterinary Clinic'),
          Clinic(id: 'clinic-1', name: 'Sunrise Veterinary Clinic'),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(home: DogFormPage(repository: repo, dog: dog)),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('Sunrise Veterinary Clinic'), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('Sunrise Veterinary Clinic'), findsOneWidget);
    });

    testWidgets("a clinic missing from the partner list keeps the dog's linkage",
        (tester) async {
      const dog = Dog(
        id: 'dog-1',
        ownerUserId: 'user-1',
        name: 'Biscuit',
        clinicId: 'clinic-gone',
      );
      final repo = FakeRepository(
        dogs: const [dog],
        clinics: const [Clinic(id: 'clinic-1', name: 'Sunrise Veterinary Clinic')],
      );
      await tester.pumpWidget(
        MaterialApp(home: DogFormPage(repository: repo, dog: dog)),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // Placeholder keeps the value valid instead of silently unlinking.
      await tester.scrollUntilVisible(find.text('Your current clinic'), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('Your current clinic'), findsOneWidget);
    });
  });

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
