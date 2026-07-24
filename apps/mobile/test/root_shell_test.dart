import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furfeel_mobile/data/settings_controller.dart';
import 'package:furfeel_mobile/models/models.dart';
import 'package:furfeel_mobile/pages/root_shell.dart';

import 'fakes.dart';

const _dog = Dog(
  id: 'dog-1',
  ownerUserId: 'user-1',
  name: 'Biscuit',
  breed: 'Golden Retriever',
  clinicId: 'clinic-1',
);

const _mochi = Dog(id: 'dog-2', ownerUserId: 'user-1', name: 'Mochi', breed: 'Shiba Inu');

TelemetryReading reading({int? hr = 92, int? rr = 22}) => TelemetryReading(
      id: 'r1',
      dogId: 'dog-1',
      capturedAt: DateTime.now().subtract(const Duration(minutes: 2)),
      heartRateBpm: hr,
      respiratoryRateBpm: rr,
      bodyTemperatureC: 38.5,
      motionActivity: 0.3,
    );

Widget app(FakeRepository repository) => SettingsScope(
      controller: SettingsController(repository),
      child: MaterialApp(
        // Tests run under reduced motion so ambient loops (e.g. the Activity
        // paw bobbing while the dog is moving) go static and pumpAndSettle
        // settles -- same code path a reduced-motion user gets.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: RootShell(
          repository: repository,
          userEmail: 'owner@example.com',
          onSignOut: () async {},
        ),
      ),
    );

/// The bottom bar is icon-only, so tabs are found by their accessible name
/// rather than visible text (FloatingNavBar keeps the label in Semantics).
/// Anchored, and tolerant of the ", N new" suffix a badged tab carries.
Finder navTab(String label) =>
    find.bySemanticsLabel(RegExp('^${RegExp.escape(label)}(,|\$)'));

void main() {
  testWidgets('status hero shows dog name, stress pill, vitals, and last-updated',
      (tester) async {
    final repo = FakeRepository(
      dogs: const [_dog],
      latestReading: reading(),
      latestClassification: StressClassification(
        id: 'c1',
        dogId: 'dog-1',
        stressLevel: StressLevel.calm,
        createdAt: DateTime.now(),
      ),
      recentReadings: [reading()],
      // Paired + reporting: the setup checklist stays hidden for this fixture.
      device: const Device(id: 'device-1', deviceCode: 'FF-1', status: 'active'),
    );
    await tester.pumpWidget(app(repo));
    await tester.pumpAndSettle();

    expect(find.text('Biscuit'), findsWidgets); // header switcher chip
    expect(find.text('Calm'), findsOneWidget);
    expect(find.text('Biscuit is calm right now'), findsOneWidget);
    expect(find.textContaining('Last updated'), findsOneWidget);
    
    // Scroll to vitals so 92 bpm is built/rendered in the lazy ListView
    await tester.scrollUntilVisible(
      find.textContaining('92 bpm', findRichText: true),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('92 bpm', findRichText: true), findsOneWidget);
    expect(repo.subscribeCalls, 1); // realtime subscription established once
  });

  testWidgets('care insights card shows guidance for the current stress level',
      (tester) async {
    final repo = FakeRepository(
      dogs: const [_dog],
      latestClassification: StressClassification(
        id: 'c1',
        dogId: 'dog-1',
        stressLevel: StressLevel.mild,
        createdAt: DateTime.now(),
      ),
      guidance: const [
        CareGuidance(stressLevel: StressLevel.mild, title: 'A little uneasy', body: 'Offer a quiet spot.'),
        CareGuidance(stressLevel: StressLevel.high, title: 'Needs attention', body: 'Check promptly.'),
      ],
    );
    await tester.pumpWidget(app(repo));
    await tester.pumpAndSettle();

    // Care Insights sits on Vitals now (the landing tab) -- the Care Team tab
    // was retired once the vet-note feed moved to Chat.
    expect(find.text('Care Team'), findsNothing);
    await tester.scrollUntilVisible(find.text('A little uneasy'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.text('A little uneasy'), findsOneWidget);
    expect(find.text('Offer a quiet spot.'), findsOneWidget);
    expect(find.textContaining('not a diagnosis'), findsOneWidget);
    expect(find.text('Needs attention'), findsNothing); // only the current level
  });

  testWidgets('alerts tab lists alerts, acknowledges, and badges the open count',
      (tester) async {
    final repo = FakeRepository(
      dogs: const [_dog],
      alerts: [
        Alert(
          id: 'a1',
          dogId: 'dog-1',
          severity: 'critical',
          type: 'high_stress',
          message: 'Biscuit is showing high stress',
          status: 'open',
          createdAt: DateTime.now(),
        ),
      ],
    );
    await tester.pumpWidget(app(repo));
    await tester.pumpAndSettle();

    // Open-alert badge on the tab.
    expect(
      find.descendant(of: find.byType(Badge), matching: find.text('1')),
      findsOneWidget,
    );

    await tester.tap(navTab('Alerts'));
    await tester.pumpAndSettle();
    expect(find.text('Biscuit is showing high stress'), findsOneWidget);

    await tester.tap(find.text('Acknowledge'));
    await tester.pumpAndSettle();
    expect(repo.acknowledgedIds, ['a1']);
    expect(find.text('Acknowledge'), findsNothing);
  });

  testWidgets('alert type tabs filter and mute per type', (tester) async {
    Alert alert(String id, String type, String message) => Alert(
          id: id,
          dogId: 'dog-1',
          severity: 'warning',
          type: type,
          message: message,
          status: 'open',
          createdAt: DateTime.now(),
        );
    final repo = FakeRepository(
      dogs: const [_dog],
      alerts: [
        alert('a1', 'high_stress', 'Stress is high'),
        alert('a2', 'device_offline', 'Harness went offline'),
      ],
    );
    await tester.pumpWidget(app(repo));
    await tester.pumpAndSettle();

    await tester.tap(navTab('Alerts'));
    await tester.pumpAndSettle();

    // All tab shows both; Harness tab filters to device alerts.
    expect(find.text('Stress is high'), findsOneWidget);
    expect(find.text('Harness went offline'), findsOneWidget);
    await tester.tap(find.text('Harness'));
    await tester.pumpAndSettle();
    expect(find.text('Stress is high'), findsNothing);
    expect(find.text('Harness went offline'), findsOneWidget);

    // Muting the harness type persists to user_settings.
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    // The Harness group now covers connectivity + battery health.
    expect(repo.userSettings.mutedAlertTypes, ['device_offline', 'low_battery']);
  });

  testWidgets('dog switcher swaps the selected dog and reloads its data', (tester) async {
    final repo = FakeRepository(dogs: const [_dog, _mochi], recentReadings: [reading()]);
    await tester.pumpWidget(app(repo));
    await tester.pumpAndSettle();

    expect(find.text('Biscuit'), findsWidgets);

    // Owner feedback: the switcher chip is hidden on the multi-dog Home (the
    // cards are the dog list) but still lives on the other tabs.
    expect(find.byTooltip('Switch dog'), findsNothing);
    await tester.tap(navTab('Alerts'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Switch dog'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mochi').last);
    await tester.pumpAndSettle();

    expect(find.text('Mochi'), findsWidgets);
    expect(repo.subscribeCalls, 2); // one per selected dog
  });

  testWidgets('vital square opens the detail screen with a typical range',
      (tester) async {
    final repo = FakeRepository(
      dogs: const [_dog],
      latestReading: reading(),
      device: const Device(id: 'device-1', deviceCode: 'FF-1', status: 'active'),
    );
    await tester.pumpWidget(app(repo));
    await tester.pumpAndSettle();

    // Scroll to the Heart rate vital square in the lazy ListView before tapping
    await tester.scrollUntilVisible(
      find.text('Heart rate'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Heart rate'));
    await tester.pumpAndSettle();

    expect(find.text('TYPICAL AT REST'), findsOneWidget);
    expect(find.textContaining('60–120 bpm'), findsOneWidget); // general default
  });

  testWidgets('no dogs yet → guided setup steps instead of an empty dashboard',
      (tester) async {
    final repo = FakeRepository();
    await tester.pumpWidget(app(repo));
    await tester.pumpAndSettle();

    expect(find.textContaining('Welcome'), findsOneWidget);
    expect(find.text('Add your dog'), findsOneWidget);
    expect(find.text('Pair the harness'), findsOneWidget);
    expect(repo.subscribeCalls, 0);
  });

  testWidgets('profile tab lists dogs with clinic linkage state', (tester) async {
    final repo = FakeRepository(dogs: const [_dog, _mochi]);
    await tester.pumpWidget(app(repo));
    await tester.pumpAndSettle();

    await tester.tap(navTab('Profile'));
    await tester.pumpAndSettle();

    expect(find.textContaining('owner@example.com'), findsWidgets); // account card
    expect(find.text('Settings'), findsOneWidget);
    // The dog list sits below the fold of the lazy ListView — scroll to it.
    await tester.scrollUntilVisible(find.textContaining('Home only'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('Clinic-monitored'), findsOneWidget); // Biscuit
    expect(find.textContaining('Home only'), findsOneWidget); // Mochi
  });

  testWidgets('trends tab shows the calm hero, chart, insights, and log link',
      (tester) async {
    final today = DateTime.now();
    DailyStressSummary summary(int daysAgo, int calm, int high) => DailyStressSummary(
          day: DateTime(today.year, today.month, today.day)
              .subtract(Duration(days: daysAgo)),
          calm: calm,
          mild: 0,
          moderate: 0,
          high: high,
        );
    final repo = FakeRepository(
      dogs: const [_dog],
      dailySummaries: [
        for (var i = 0; i < 7; i++) summary(i, 90, 10), // this week 90%
        for (var i = 7; i < 14; i++) summary(i, 50, 50), // last week 50%
      ],
    );
    await tester.pumpWidget(app(repo));
    await tester.pumpAndSettle();

    await tester.tap(navTab('Trends'));
    await tester.pumpAndSettle();

    expect(find.text('CALM TIME THIS WEEK'), findsOneWidget);
    expect(find.text('90%'), findsOneWidget);
    expect(find.textContaining('vs last week'), findsOneWidget);

    // Insight cards + log link sit below the chart — scroll them into view.
    await tester.scrollUntilVisible(find.textContaining('not a diagnosis'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('More calm time this week'), findsOneWidget); // insight card
    expect(find.text('View detailed log'), findsOneWidget);
    expect(find.textContaining('not a diagnosis'), findsOneWidget);
  });

  testWidgets('trends tab with no data invites the owner instead of empty charts',
      (tester) async {
    final repo = FakeRepository(dogs: const [_dog]);
    await tester.pumpWidget(app(repo));
    await tester.pumpAndSettle();

    await tester.tap(navTab('Trends'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Trends appear after a day or two'), findsOneWidget);
    expect(find.text('CALM TIME THIS WEEK'), findsNothing);
  });
}
