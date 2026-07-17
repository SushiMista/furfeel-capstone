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
            body: AlertCard(alert: a, onAcknowledge: (_) async {}),
          ),
        ),
      );

  testWidgets('open alerts carry a practical what-you-can-do tip', (tester) async {
    await pump(tester, alert('low_battery'));
    expect(find.textContaining('charger'), findsOneWidget);

    await pump(tester, alert('high_stress'));
    expect(find.textContaining('quiet, familiar spot'), findsOneWidget);

    await pump(tester, alert('device_offline'));
    expect(find.textContaining('Wi-Fi range'), findsOneWidget);
  });

  testWidgets('acknowledged alerts drop the tip', (tester) async {
    await pump(tester, alert('low_battery', status: 'acknowledged'));
    expect(find.textContaining('charger'), findsNothing);
  });
}
