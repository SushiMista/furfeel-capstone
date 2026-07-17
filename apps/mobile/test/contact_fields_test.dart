import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furfeel_mobile/data/settings_controller.dart';
import 'package:furfeel_mobile/models/models.dart';
import 'package:furfeel_mobile/pages/root_shell.dart';

import 'fakes.dart';

const _dog = Dog(id: 'dog-1', ownerUserId: 'user-1', name: 'Biscuit');

Widget app(FakeRepository repo, SettingsController controller) => SettingsScope(
      controller: controller,
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

Future<void> openProfile(WidgetTester tester) async {
  await tester.tap(find.text('Profile'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('phone number saves from the profile row and shows afterwards',
      (tester) async {
    final repo = FakeRepository(dogs: const [_dog]);
    final controller = SettingsController(repo);
    await controller.load();
    await tester.pumpWidget(app(repo, controller));
    await tester.pumpAndSettle();
    await openProfile(tester);

    await tester.tap(find.text('Phone Number'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '+63 912 345 6789');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repo.profile.phone, '+63 912 345 6789');
    expect(find.text('+63 912 345 6789'), findsOneWidget); // row subtitle
    expect(find.text('Phone Number saved'), findsOneWidget);
  });

  testWidgets('emergency contact saves and clears back to Not set',
      (tester) async {
    final repo = FakeRepository(dogs: const [_dog]);
    final controller = SettingsController(repo);
    await controller.load();
    await tester.pumpWidget(app(repo, controller));
    await tester.pumpAndSettle();
    await openProfile(tester);

    await tester.tap(find.text('Emergency Contact'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Maria Santos 0917');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(repo.profile.emergencyContact, 'Maria Santos 0917');

    // Clearing: save an empty value -> stored null, shown as Not set again.
    await tester.tap(find.text('Emergency Contact'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repo.profile.emergencyContact, isNull);
    expect(find.text('Emergency Contact cleared'), findsOneWidget);
  });

  testWidgets('cancel leaves the field untouched', (tester) async {
    final repo = FakeRepository(dogs: const [_dog]);
    repo.profile = const UserProfile(
      id: 'user-1',
      name: 'Jamie Rivera',
      email: 'owner@example.com',
      phone: '+63 900 000 0000',
    );
    final controller = SettingsController(repo);
    await controller.load();
    await tester.pumpWidget(app(repo, controller));
    await tester.pumpAndSettle();
    await openProfile(tester);

    await tester.tap(find.text('Phone Number'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'something else');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(repo.profile.phone, '+63 900 000 0000');
  });
}
