import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furfeel_mobile/models/models.dart';
import 'package:furfeel_mobile/pages/dog_form_page.dart';

import 'fakes.dart';

void main() {
  testWidgets('requires a name before saving', (tester) async {
    final repo = FakeRepository();
    await tester.pumpWidget(MaterialApp(home: DogFormPage(repository: repo)));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Add dog'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Add dog'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Every pup needs a name'), -200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Every pup needs a name'), findsOneWidget);
    expect(repo.lastCreatedDraft, isNull);
  });

  testWidgets('creates a dog with the selected clinic linkage', (tester) async {
    final repo = FakeRepository(
      clinics: const [Clinic(id: 'clinic-1', name: 'Sunrise Veterinary Clinic')],
    );
    await tester.pumpWidget(MaterialApp(home: DogFormPage(repository: repo)));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Mochi');
    await tester.pumpAndSettle();

    // Clinic linkage (docs/04): pick the clinic so the dog lands on its board.
    await tester.scrollUntilVisible(find.text('Home monitoring only'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Home monitoring only'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sunrise Veterinary Clinic').last);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Add Mochi'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.text('Add Mochi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Mochi'));
    await tester.pumpAndSettle();

    expect(repo.lastCreatedDraft?.name, 'Mochi');
    expect(repo.lastCreatedDraft?.clinicId, 'clinic-1');
  });

  testWidgets('validates that weight is numeric', (tester) async {
    final repo = FakeRepository();
    await tester.pumpWidget(MaterialApp(home: DogFormPage(repository: repo)));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Mochi');
    await tester.scrollUntilVisible(
        find.widgetWithText(TextFormField, 'Weight in kg (optional)'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Weight in kg (optional)'), 'heavy');
    // Submit via the button's handler — the exact scroll offset of the CTA
    // isn't what this test is about, the validator is.
    tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed!();
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Numbers only, e.g. 12.5'), -200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Numbers only, e.g. 12.5'), findsOneWidget);
    expect(repo.lastCreatedDraft, isNull);
  });
}
