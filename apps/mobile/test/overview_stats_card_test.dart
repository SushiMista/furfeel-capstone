import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furfeel_mobile/data/settings_controller.dart';
import 'package:furfeel_mobile/models/models.dart';
import 'package:furfeel_mobile/pages/root_shell.dart';
import 'package:furfeel_mobile/widgets/overview_stats_card.dart';

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
        home: RootShell(
          repository: repo,
          userEmail: 'owner@example.com',
          onSignOut: () async {},
        ),
      ),
    );

void main() {
  testWidgets('single-dog home shows the overview strip from already-loaded data',
      (tester) async {
    final repo = FakeRepository(
      dogs: const [_biscuit],
      latestClassification: StressClassification(
        id: 'c1',
        dogId: 'dog-1',
        stressLevel: StressLevel.moderate,
        createdAt: DateTime.now(),
      ),
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
      device: const Device(id: 'device-1', deviceCode: 'FF-1', status: 'offline'),
    );

    await tester.pumpWidget(app(repo));
    await tester.pumpAndSettle();

    final card = find.byType(OverviewStatsCard);
    expect(card, findsOneWidget);
    expect(find.descendant(of: card, matching: find.text('Dog monitored')), findsOneWidget);
    expect(find.descendant(of: card, matching: find.text('1 ')), findsOneWidget);
    expect(find.descendant(of: card, matching: find.text('1 Needs attention')), findsOneWidget);
  });

  testWidgets('multi-dog home aggregates the pack from the already-fetched overviews',
      (tester) async {
    final repo = FakeRepository(
      dogs: const [_biscuit, _mochi],
      latestClassification: StressClassification(
        id: 'c1',
        dogId: 'dog-1',
        stressLevel: StressLevel.high,
        createdAt: DateTime.now(),
      ),
      device: const Device(id: 'device-1', deviceCode: 'FF-1', status: 'offline'),
    );

    await tester.pumpWidget(app(repo));
    await tester.pumpAndSettle();

    final card = find.byType(OverviewStatsCard);
    expect(card, findsOneWidget);
    expect(find.descendant(of: card, matching: find.text('Dogs monitored')), findsOneWidget);
    expect(find.descendant(of: card, matching: find.text('2 ')), findsOneWidget);
    expect(find.descendant(of: card, matching: find.text('2 Needs attention')), findsOneWidget);
  });
}
