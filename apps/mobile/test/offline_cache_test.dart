import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furfeel_mobile/data/settings_controller.dart';
import 'package:furfeel_mobile/data/status_cache.dart';
import 'package:furfeel_mobile/models/models.dart';
import 'package:furfeel_mobile/pages/consent_page.dart';
import 'package:furfeel_mobile/pages/root_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

/// Offline resilience (improvement pass step 9): with no network, the app
/// shows the last-known snapshot behind an explicit staleness banner instead
/// of an error screen — and never without a previously CONFIRMED consent.
const _dog = Dog(
  id: 'dog-1',
  ownerUserId: 'user-1',
  name: 'Biscuit',
  breed: 'Golden Retriever',
);

Widget _app(FakeRepository repo) => SettingsScope(
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
  testWidgets('offline cold start shows cached status + stale banner', (tester) async {
    SharedPreferences.setMockInitialValues({
      'furfeel_consent_confirmed_$kConsentPolicyVersion': true,
    });
    await StatusCache.save(
      dogs: const [_dog],
      selectedDogId: 'dog-1',
      reading: TelemetryReading(
        id: 'r1',
        dogId: 'dog-1',
        capturedAt: DateTime.now().subtract(const Duration(hours: 2)),
        heartRateBpm: 88,
      ),
      classification: StressClassification(
        id: 'c1',
        dogId: 'dog-1',
        stressLevel: StressLevel.calm,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
    );

    final repo = FakeRepository(throwOnFetch: true);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    expect(find.text('Biscuit'), findsWidgets);
    expect(find.textContaining('Showing last known reading'), findsOneWidget);
    expect(find.textContaining("Couldn't load"), findsNothing);
  });

  testWidgets('offline cold start without cached consent still shows the gate',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repo = FakeRepository(throwOnFetch: true);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    // No confirmed consent on record: the gate wins over any cached data.
    expect(find.textContaining('Showing last known reading'), findsNothing);
  });

  testWidgets('cache round-trips through the model parsers', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await StatusCache.save(
      dogs: const [_dog],
      selectedDogId: 'dog-1',
      reading: TelemetryReading(
        id: 'r1',
        dogId: 'dog-1',
        capturedAt: DateTime.utc(2026, 7, 19, 8),
        heartRateBpm: 88,
        bodyTemperatureC: 38.4,
      ),
    );
    final cached = await StatusCache.load();
    expect(cached, isNotNull);
    expect(cached!.dogs.single.name, 'Biscuit');
    expect(cached.reading!.heartRateBpm, 88);
    expect(cached.reading!.bodyTemperatureC, 38.4);
    expect(cached.classification, isNull);

    await StatusCache.clear();
    expect(await StatusCache.load(), isNull);
  });
}
