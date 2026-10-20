import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:furfeel_mobile/data/ble_provisioning_service.dart';
import 'package:furfeel_mobile/widgets/wifi_provisioning_modal.dart';
import 'package:furfeel_mobile/theme/furfeel_tokens.dart';

class FakeProvisioning extends BleProvisioningService {
  String? sentPassword;
  bool fail = false;
  bool failConnect = false;
  @override
  Future<List<BleDiscoveredCollar>> findCollars() async => [
    BleDiscoveredCollar(
      device: BluetoothDevice.fromId('AA:BB:CC:DD:EE:FF'),
      name: 'FurFeel Test',
      rssi: -40,
    ),
  ];
  @override
  Future<void> connect(BluetoothDevice device) async {
    if (failConnect) throw const BleException('GATT_CONNECTION_TIMEOUT');
  }

  @override
  Future<List<WifiNetwork>> scanNetworks() async => [
    const WifiNetwork(ssid: 'Home', rssi: -45, secured: true),
    const WifiNetwork(ssid: 'Guest', rssi: -65, secured: false),
  ];
  @override
  Future<void> sendCredentialsToCollar({
    required BluetoothDevice device,
    required String ssid,
    required String password,
  }) async {
    sentPassword = password;
    if (fail) throw const BleException('Could not join Wi-Fi.');
  }

  @override
  Future<void> stopScan() async {}
  @override
  Future<void> disconnect() async {}
}

void main() {
  testWidgets(
    'Bluetooth connection failure does not offer a Wi-Fi form or claim an empty scan',
    (tester) async {
      final service = FakeProvisioning()..failConnect = true;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: [FurFeelPalette.light]),
          home: Scaffold(body: WifiProvisioningModal(service: service)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Connect harness'), findsNothing);
      expect(find.text('Enter a hidden network'), findsNothing);
      expect(find.textContaining('No visible networks'), findsNothing);
      expect(
        find.textContaining('Wi-Fi details were not sent'),
        findsOneWidget,
      );
    },
  );
  test(
    'credential encoding preserves punctuation, unicode and password spaces',
    () {
      const ssid = 'Home;:犬';
      const password = ' pass;:word ';
      final fields = wifiCredentialsPayload(ssid, password).split(':');
      expect(decodeWifiText(fields[1]), ssid);
      expect(decodeWifiText(fields[2]), password);
      expect(
        () => wifiCredentialsPayload('a' * 33, ''),
        throwsA(isA<BleException>()),
      );
    },
  );
  test('network response retains security and signal', () {
    final n = WifiNetwork.parse('N:0:-42:0:${encodeWifiText('Guest')}');
    expect(n.ssid, 'Guest');
    expect(n.rssi, -42);
    expect(n.secured, false);
  });
  Future<void> show(WidgetTester tester, FakeProvisioning service) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [FurFeelPalette.light]),
        home: Scaffold(body: WifiProvisioningModal(service: service)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'secured network preserves password whitespace on a narrow phone',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = FakeProvisioning();
      await show(tester, service);
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(TextField));
      await tester.enterText(find.byType(TextField), ' pass word ');
      await tester.ensureVisible(find.text('Connect harness'));
      await tester.tap(find.text('Connect harness'));
      await tester.pumpAndSettle();
      expect(service.sentPassword, ' pass word ');
      expect(find.text('Harness connected to Wi-Fi'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('open networks connect without asking for a password', (
    tester,
  ) async {
    final service = FakeProvisioning();
    await show(tester, service);
    await tester.tap(find.text('Guest'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.text('Connect harness'));
    await tester.pumpAndSettle();
    expect(service.sentPassword, '');
    expect(find.text('Harness connected to Wi-Fi'), findsOneWidget);
  });
  testWidgets('failed connection does not display success', (tester) async {
    final service = FakeProvisioning()..fail = true;
    await show(tester, service);
    await tester.tap(find.text('Guest'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Connect harness'));
    await tester.pumpAndSettle();
    expect(find.text('Harness connected to Wi-Fi'), findsNothing);
    expect(find.text('Could not join Wi-Fi.'), findsOneWidget);
  });
}
