import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furfeel_mobile/widgets/harness_battery.dart';
import 'package:furfeel_mobile/models/models.dart';
import 'package:furfeel_mobile/theme/furfeel_tokens.dart';
void main() {
  Future<void> show(WidgetTester tester, {int? percent, String status = 'active'}) async {
    await tester.pumpWidget(MaterialApp(theme: ThemeData(extensions: [FurFeelPalette.light]), home: Scaffold(body: HarnessBattery(device: Device(id:'d',deviceCode:'FURFEEL',status:status,batteryPercent:percent)))));
  }
<<<<<<< HEAD
  testWidgets('reports harness percentage', (tester) async {
    await show(tester, percent:82); expect(find.text('Harness battery: 82%'),findsOneWidget);
  });
  testWidgets('zero is a real low battery, with offline context', (tester) async {
    await show(tester, percent:0, status:'offline'); expect(find.text('Harness battery: 0% · Low · Offline'),findsOneWidget);
  });
  testWidgets('missing or invalid data is unavailable, never fake zero', (tester) async {
    await show(tester); expect(find.text('Harness battery: Unavailable'),findsOneWidget);
    await show(tester,percent:101); expect(find.text('Harness battery: Unavailable'),findsOneWidget);
=======
  testWidgets('shows only the percentage, with the full spoken label', (tester) async {
    await show(tester, percent:82);
    expect(find.text('82%'),findsOneWidget);
    expect(find.bySemanticsLabel('Harness battery: 82%'),findsOneWidget);
    expect(find.byIcon(Icons.wifi_off),findsNothing);
  });
  testWidgets('zero is a real low battery, with offline context', (tester) async {
    await show(tester, percent:0, status:'offline');
    expect(find.text('0%'),findsOneWidget);
    expect(find.byIcon(Icons.battery_alert),findsOneWidget);
    expect(find.byIcon(Icons.wifi_off),findsOneWidget);
    expect(find.bySemanticsLabel('Harness battery: 0% · Low · Offline'),findsOneWidget);
  });
  testWidgets('missing or invalid data is unavailable, never fake zero', (tester) async {
    await show(tester);
    expect(find.text('--'),findsOneWidget);
    expect(find.bySemanticsLabel('Harness battery: Unavailable'),findsOneWidget);
    await show(tester,percent:101);
    expect(find.byIcon(Icons.battery_unknown),findsOneWidget);
    expect(find.bySemanticsLabel('Harness battery: Unavailable'),findsOneWidget);
>>>>>>> 20e52663b2b04379741610740390fdb8af7f9fb9
  });
}
