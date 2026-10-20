import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furfeel_mobile/widgets/harness_battery.dart';
import 'package:furfeel_mobile/models/models.dart';
import 'package:furfeel_mobile/theme/furfeel_tokens.dart';
void main() {
  Future<void> show(WidgetTester tester, {int? percent, String status = 'active'}) async {
    await tester.pumpWidget(MaterialApp(theme: ThemeData(extensions: [FurFeelPalette.light]), home: Scaffold(body: HarnessBattery(device: Device(id:'d',deviceCode:'FURFEEL',status:status,batteryPercent:percent)))));
  }
  testWidgets('reports harness percentage', (tester) async {
    await show(tester, percent:82); expect(find.text('Harness battery: 82%'),findsOneWidget);
  });
  testWidgets('zero is a real low battery, with offline context', (tester) async {
    await show(tester, percent:0, status:'offline'); expect(find.text('Harness battery: 0% · Low · Offline'),findsOneWidget);
  });
  testWidgets('missing or invalid data is unavailable, never fake zero', (tester) async {
    await show(tester); expect(find.text('Harness battery: Unavailable'),findsOneWidget);
    await show(tester,percent:101); expect(find.text('Harness battery: Unavailable'),findsOneWidget);
  });
}
