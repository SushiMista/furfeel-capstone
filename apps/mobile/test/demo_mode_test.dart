import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furfeel_mobile/data/demo_repository.dart';
import 'package:furfeel_mobile/data/furfeel_repository.dart';
import 'package:furfeel_mobile/data/settings_controller.dart';
import 'package:furfeel_mobile/models/models.dart';
import 'package:furfeel_mobile/pages/root_shell.dart';

/// Demo mode (improvement pass step 10): a full week of realistic sample data
/// with no account, no hardware, no network — clearly labeled.
void main() {
  test('demo data tells the intended story', () async {
    final repo = DemoRepository();
    final dogs = await repo.fetchDogs();
    expect(dogs.single.name, 'Buddy');

    final readings = await repo.fetchRecentReadings('demo-dog', limit: 5000);
    expect(readings.length, greaterThan(900), reason: 'a week of 10-min samples');

    final daily = await repo.fetchDailyStressSummary('demo-dog');
    expect(daily.length, greaterThanOrEqualTo(7));
    // The warm-afternoon spell must register above calm somewhere.
    final levels = await repo.fetchRecentClassifications('demo-dog', limit: 2000);
    expect(levels.any((c) => c.stressLevel == StressLevel.moderate), isTrue);

    // One open alert to acknowledge, and acknowledging works in-memory.
    final alerts = await repo.fetchAlerts('demo-dog');
    expect(alerts.single.status, 'open');
    final acked = await repo.acknowledgeAlert(alerts.single.id);
    expect(acked!.status, 'acknowledged');

    // Consent is auto-satisfied: the gate protects real data, not samples.
    expect(await repo.hasAcceptedConsent('any'), isTrue);

    // Writes are refused with friendly copy, never silently swallowed.
    expect(
      () => repo.createDog(const DogDraft(name: 'X')),
      throwsA(isA<FurFeelDataException>()),
    );
  });

  testWidgets('demo shell shows the sample-data banner and the dog', (tester) async {
    await tester.pumpWidget(
      SettingsScope(
        controller: SettingsController(DemoRepository()),
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: RootShell(
            repository: DemoRepository(),
            demo: true,
            onSignOut: () async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Demo mode — sample data'), findsOneWidget);
    expect(find.text('Buddy'), findsWidgets);
  });
}
