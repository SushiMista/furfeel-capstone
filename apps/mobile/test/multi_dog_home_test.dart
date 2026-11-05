import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furfeel_mobile/data/settings_controller.dart';
import 'package:furfeel_mobile/models/models.dart';
import 'package:furfeel_mobile/screens/home/multi_dog_home.dart';
<<<<<<< HEAD
=======
import 'package:furfeel_mobile/theme/furfeel_tokens.dart';
>>>>>>> 20e52663b2b04379741610740390fdb8af7f9fb9

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

    // The name also appears in the pet-selector strip now, so scope the
    // "one card per dog" assertion to the card itself.
    Finder nameInCard(String name) => find.descendant(
        of: find.byType(DogOverviewCard), matching: find.text(name));
    expect(nameInCard('Biscuit'), findsOneWidget);
    expect(nameInCard('Mochi'), findsOneWidget);
    expect(find.text('Calm'), findsWidgets); // stress pill
    // Harness battery is visible without opening each dog; wellness stays in detail.
    expect(find.text('82'), findsNothing);
<<<<<<< HEAD
    expect(find.text('Harness battery: 12% · Low'), findsNWidgets(2));
    expect(find.byIcon(Icons.battery_alert), findsNWidgets(2));
=======
    expect(find.text('12%'), findsNWidgets(2));
    expect(find.byIcon(Icons.battery_alert), findsNWidgets(2));
  });

  testWidgets('battery and a long stress word share the top row on a small phone',
      (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeRepository(
      dogs: const [_biscuit, _mochi],
      latestClassification: StressClassification(
        id: 'c1',
        dogId: 'dog-1',
        stressLevel: StressLevel.moderate,
        createdAt: DateTime.now(),
      ),
      device: const Device(
        id: 'device-1',
        deviceCode: 'FF-1',
        status: 'offline',
        batteryPercent: 100,
      ),
    );

    await tester.pumpWidget(app(repo));
    await tester.pumpAndSettle();

    expect(find.text('Moderate'), findsNWidgets(2));
    expect(find.byIcon(Icons.wifi_off), findsNWidgets(2));
    expect(tester.takeException(), isNull);
>>>>>>> 20e52663b2b04379741610740390fdb8af7f9fb9
  });

  testWidgets('a card opens the full dog detail', (tester) async {
    final repo = FakeRepository(dogs: const [_biscuit, _mochi]);
    await tester.pumpWidget(app(repo));
    await tester.pumpAndSettle();

    final cardName = find.descendant(
        of: find.byType(DogOverviewCard), matching: find.text('Biscuit'));
    await tester.ensureVisible(cardName);
    await tester.pumpAndSettle();
    await tester.tap(cardName);
    await tester.pumpAndSettle();

    // The dog's immersive home detail (no app bar now — a floating back button).
    expect(find.byTooltip('Back'), findsOneWidget);
    expect(find.textContaining('Waiting for the first reading'),
        findsOneWidget);

    // Back scrolls with the hero, then sticks at the top and stays tappable.
    final back = find.byTooltip('Back');
    final restTop = tester.getTopLeft(back).dy;
    final stuckTop = restTop - FurFeelTokens.space5 + FurFeelTokens.space1;
    await tester.dragFrom(const Offset(200, 400), const Offset(0, -8),
        touchSlopY: 0);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(back).dy, restTop - 8);
    await tester.dragFrom(const Offset(200, 400), const Offset(0, -100),
        touchSlopY: 0);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(back).dy, stuckTop);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Waiting for the first reading'), findsNothing);
  });
}
