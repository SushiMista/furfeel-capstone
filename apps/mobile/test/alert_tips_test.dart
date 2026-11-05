import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furfeel_mobile/models/models.dart';
import 'package:furfeel_mobile/widgets/alert_card.dart';

Alert alert(String type, {String status = 'open'}) => Alert(
      id: 'a-$type',
      dogId: 'dog-1',
      severity: 'warning',
      type: type,
      message: 'The harness battery is getting low (12%).',
      status: status,
      createdAt: DateTime.now(),
    );

void main() {
  Future<void> pump(WidgetTester tester, Alert a) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AlertCard(
              key: ValueKey(a.type),
              alert: a,
              onAcknowledge: (_) async {},
            ),
          ),
        ),
      );

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();
  }

  testWidgets('a short title leads and the details drop down on tap', (tester) async {
    await pump(
      tester,
      Alert(
        id: 'a2',
        dogId: 'dog-1',
        severity: 'warning',
        type: 'device_offline',
        message: 'Device FURFEEL-DEV-0002 stopped sending data '
            '(last seen 2026-11-05 14:32 PST).',
        status: 'open',
        createdAt: DateTime.now(),
      ),
    );
    expect(find.text('Device stopped sending data'), findsOneWidget);
    expect(find.text('Got it'), findsOneWidget);
    expect(find.textContaining('FURFEEL-DEV-0002'), findsNothing);
    expect(find.textContaining('back in range'), findsNothing);

    await open(tester);
    expect(find.text('FURFEEL-DEV-0002 · Last seen 2:32 PM'), findsOneWidget);
    expect(find.textContaining('back in range'), findsOneWidget);

    await open(tester);
    expect(find.textContaining('FURFEEL-DEV-0002'), findsNothing);
  });

  testWidgets('each alert type carries a practical what-you-can-do tip', (tester) async {
    await pump(tester, alert('low_battery'));
    await open(tester);
    expect(find.textContaining('charger'), findsOneWidget);

    await pump(tester, alert('high_stress'));
    await open(tester);
    expect(find.textContaining('quiet, familiar spot'), findsOneWidget);
  });

  testWidgets('past alerts drop the tip and say how they ended', (tester) async {
    await pump(tester, alert('low_battery', status: 'acknowledged'));
    await open(tester);
    expect(find.textContaining('charger'), findsNothing);
    expect(
      find.text('Seen · The harness battery is getting low (12%).'),
      findsOneWidget,
    );
    expect(find.text('Got it'), findsNothing);
  });
}
