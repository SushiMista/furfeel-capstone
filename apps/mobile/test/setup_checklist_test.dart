import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furfeel_mobile/data/settings_controller.dart';
import 'package:furfeel_mobile/models/models.dart';
import 'package:furfeel_mobile/pages/device_pairing_page.dart';
import 'package:furfeel_mobile/pages/home_tab.dart';

import 'fakes.dart';

const _dog = Dog(id: 'dog-1', ownerUserId: 'user-1', name: 'Biscuit');

Widget app(FakeRepository repo) => SettingsScope(
      controller: SettingsController(repo),
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(
          body: HomeTab(
            repository: repo,
            dog: _dog,
            reading: null,
            classification: null,
            daily: const [],
            device: null,
            guidance: const [],
            vetNotes: const [],
            onRefresh: () async {},
          ),
        ),
      ),
    );

void main() {
  testWidgets('new owner sees the setup checklist with the next steps',
      (tester) async {
    await tester.pumpWidget(app(FakeRepository(dogs: const [_dog])));
    await tester.pumpAndSettle();

    expect(find.textContaining('FINISH SETTING UP'), findsOneWidget);
    expect(find.text('Pair the harness'), findsOneWidget);
    expect(find.text('Choose a clinic (optional)'), findsOneWidget);
    expect(find.text('0 of 3'), findsOneWidget);
  });

  testWidgets('tapping the harness step opens Device Pairing', (tester) async {
    await tester.pumpWidget(app(FakeRepository(dogs: const [_dog])));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pair the harness'));
    await tester.pumpAndSettle();

    expect(find.byType(DevicePairingPage), findsOneWidget);
  });

  testWidgets('checklist hides once the harness reports', (tester) async {
    final repo = FakeRepository(
      dogs: const [_dog],
      device: const Device(id: 'device-1', deviceCode: 'FF-1', status: 'active'),
      latestReading: TelemetryReading(
        id: 'r1',
        dogId: 'dog-1',
        capturedAt: DateTime.now(),
        heartRateBpm: 92,
      ),
    );
    await tester.pumpWidget(SettingsScope(
      controller: SettingsController(repo),
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(
          body: HomeTab(
            repository: repo,
            dog: _dog,
            reading: repo.latestReading,
            classification: null,
            daily: const [],
            device: repo.device,
            guidance: const [],
            vetNotes: const [],
            onRefresh: () async {},
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('FINISH SETTING UP'), findsNothing);
  });
}
