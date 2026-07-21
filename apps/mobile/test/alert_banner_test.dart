import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furfeel_mobile/data/settings_controller.dart';
import 'package:furfeel_mobile/models/models.dart';
import 'package:furfeel_mobile/pages/root_shell.dart';

import 'fakes.dart';

const _dog = Dog(id: 'dog-1', ownerUserId: 'user-1', name: 'Biscuit');

Alert alert(String type) => Alert(
      id: 'a1',
      dogId: 'dog-1',
      severity: 'critical',
      type: type,
      message: 'Biscuit seems quite stressed right now. Please check on them soon.',
      status: 'open',
      createdAt: DateTime.now(),
    );

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

void main() {
  testWidgets('a live alert shows a gentle in-app banner with a View action',
      (tester) async {
    final repo = FakeRepository(dogs: const [_dog]);
    await tester.pumpWidget(app(repo, SettingsController(repo)));
    await tester.pumpAndSettle();

    repo.lastOnAlert!(alert('high_stress'));
    // Let the snackbar finish sliding in before interacting with it.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.textContaining('Biscuit seems quite stressed'), findsOneWidget);
    // Severity as word + icon (docs/19), never color alone.
    expect(find.descendant(of: find.byType(SnackBar), matching: find.text('Critical')),
        findsOneWidget);
    expect(
        find.descendant(
            of: find.byType(SnackBar), matching: find.byIcon(Icons.warning_amber_rounded)),
        findsOneWidget);

    await tester.tap(find.text('View'));
    await tester.pumpAndSettle();
    // Landed on the Alerts tab (its type-group tabs are visible).
    expect(find.text('Harness'), findsOneWidget);
  });

  testWidgets('muted types and the master toggle suppress the banner',
      (tester) async {
    final repo = FakeRepository(dogs: const [_dog])
      ..userSettings = const UserSettings(mutedAlertTypes: ['high_stress']);
    final controller = SettingsController(repo);
    await controller.load();
    await tester.pumpWidget(app(repo, controller));
    await tester.pumpAndSettle();

    repo.lastOnAlert!(alert('high_stress'));
    await tester.pump();
    expect(find.byType(SnackBar), findsNothing);
  });
}
