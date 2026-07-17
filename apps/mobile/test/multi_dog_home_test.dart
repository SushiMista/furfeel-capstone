import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furfeel_mobile/data/settings_controller.dart';
import 'package:furfeel_mobile/models/models.dart';
import 'package:furfeel_mobile/pages/multi_dog_home.dart';

import 'fakes.dart';

const _biscuit = Dog(id: 'dog-1', ownerUserId: 'user-1', name: 'Biscuit');
const _mochi = Dog(id: 'dog-2', ownerUserId: 'user-1', name: 'Mochi');

Widget app(FakeRepository repo) => SettingsScope(
      controller: SettingsController(repo),
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(
          body: MultiDogHomeTab(repository: repo, dogs: const [_biscuit, _mochi]),
        ),
      ),
    );

void main() {
  testWidgets('shows a glanceable card per dog with stress, wellness, and battery',
      (tester) async {
    final repo = FakeRepository(
      dogs: const [_biscuit, _mochi],
      latestClassification: StressClassification(
        id: 'c1',
        dogId: 'dog-1',
        stressLevel: StressLevel.calm,
        createdAt: DateTime.now(),
      ),
      latestReading: TelemetryReading(
        id: 'r1',
        dogId: 'dog-1',
        capturedAt: DateTime.now(),
        heartRateBpm: 92,
      ),
      device: const Device(
        id: 'device-1',
        deviceCode: 'FF-1',
        status: 'active',
        batteryPercent: 12,
      ),
    )..wellness = const WellnessSnapshot(
        score: 82,
        calmPercent: 90,
        activePercent: 25,
        restPercent: 40,
        alertCount: 0,
        sampleCount: 500,
      );

    await tester.pumpWidget(app(repo));
    await tester.pumpAndSettle();

    expect(find.text('Biscuit'), findsOneWidget);
    expect(find.text('Mochi'), findsOneWidget);
    expect(find.text('Calm'), findsWidgets); // stress pill
    expect(find.text('82'), findsWidgets); // wellness score
    expect(find.text('92 bpm'), findsWidgets); // key vital
    expect(find.text('12%'), findsWidgets); // low battery surfaced
    expect(find.byIcon(Icons.battery_alert), findsWidgets);
  });

  testWidgets('a card opens the full dog detail', (tester) async {
    final repo = FakeRepository(dogs: const [_biscuit, _mochi]);
    await tester.pumpWidget(app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Biscuit'));
    await tester.pumpAndSettle();

    // Detail page app bar + the rich home content underneath.
    expect(find.widgetWithText(AppBar, 'Biscuit'), findsOneWidget);
    expect(find.textContaining('No stress reading yet', findRichText: true),
        findsOneWidget);
  });
}
