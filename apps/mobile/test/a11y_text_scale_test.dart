import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furfeel_mobile/data/settings_controller.dart';
import 'package:furfeel_mobile/models/models.dart';
import 'package:furfeel_mobile/pages/root_shell.dart';

import 'fakes.dart';

/// Accessibility pass: the app must survive large dynamic type (docs/19 §9
/// "support dynamic text scaling"). Home is the densest screen — pump it at
/// 2× and fail on any overflow/exception.
const _dog = Dog(
  id: 'dog-1',
  ownerUserId: 'user-1',
  name: 'Biscuit',
  breed: 'Golden Retriever',
  clinicId: 'clinic-1',
);

void main() {
  testWidgets('Home renders at 2x text scale without overflow', (tester) async {
    final repo = FakeRepository(
      dogs: const [_dog],
      latestReading: TelemetryReading(
        id: 'r1',
        dogId: 'dog-1',
        capturedAt: DateTime.now().subtract(const Duration(minutes: 2)),
        heartRateBpm: 92,
        respiratoryRateBpm: 22,
        bodyTemperatureC: 38.5,
        motionActivity: 0.3,
      ),
      latestClassification: StressClassification(
        id: 'c1',
        dogId: 'dog-1',
        stressLevel: StressLevel.calm,
        createdAt: DateTime.now(),
      ),
    );
    await tester.pumpWidget(
      SettingsScope(
        controller: SettingsController(repo),
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: true,
              textScaler: const TextScaler.linear(2.0),
            ),
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
    expect(find.text('Biscuit'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
