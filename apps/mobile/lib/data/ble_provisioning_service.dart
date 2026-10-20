import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleDiscoveredCollar {
  final BluetoothDevice device;
  final String name;
  final int rssi;
  const BleDiscoveredCollar({
    required this.device,
    required this.name,
    required this.rssi,
  });
}

class WifiNetwork {
  final String ssid;
  final int rssi;
  final bool secured;
  const WifiNetwork({
    required this.ssid,
    required this.rssi,
    required this.secured,
  });
  static WifiNetwork parse(String value) {
    final parts = value.split(':');
    if (parts.length != 5 || parts[0] != 'N') {
      throw const BleException('Invalid network response.');
    }
    return WifiNetwork(
      ssid: decodeWifiText(parts[4]),
      rssi: int.parse(parts[2]),
      secured: parts[3] == '1',
    );
  }
}

String encodeWifiText(String value) =>
    utf8.encode(value).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
String decodeWifiText(String value) {
  if (value.length.isOdd) throw const FormatException('Invalid Wi-Fi text');
  return utf8.decode([
    for (var i = 0; i < value.length; i += 2)
      int.parse(value.substring(i, i + 2), radix: 16),
  ]);
}

String wifiCredentialsPayload(String ssid, String password) {
  if (utf8.encode(ssid).isEmpty ||
      utf8.encode(ssid).length > 32 ||
      utf8.encode(password).length > 63) {
    throw const BleException(
      'Wi-Fi name must be 1–32 bytes and password at most 63 bytes.',
    );
  }
  return 'C:${encodeWifiText(ssid)}:${encodeWifiText(password)}';
}

class BleProvisioningService {
  static const serviceUuid = '4fafc201-1fb5-459e-8fcc-c5c9c331914b';
  static const credsCharUuid = 'a3c87500-8ed3-4bdf-8a39-a01bebede295';
  static const statusCharUuid = 'cba1d466-344c-4be3-ab3f-189f80dd7518';
  static const controlCharUuid = 'f58dc8aa-6f17-4ef2-96bc-b359187d0021';
  BluetoothDevice? _device;
  BluetoothCharacteristic? _control, _status, _creds;

  Future<List<BleDiscoveredCollar>> findCollars() async {
    if (kIsWeb) {
      throw const BleException('Use the Android or iOS app for harness setup.');
    }
    if (!await FlutterBluePlus.isSupported) {
      throw const BleException('Bluetooth is unavailable.');
    }
    if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
      if (Platform.isAndroid) {
        await FlutterBluePlus.turnOn();
      } else {
        throw const BleException('Turn on Bluetooth to find your harness.');
      }
    }
    await FlutterBluePlus.startScan(
      withServices: [Guid(serviceUuid)],
      timeout: const Duration(seconds: 6),
    );
    await Future<void>.delayed(const Duration(seconds: 6));
    final results = FlutterBluePlus.lastScanResults;
    await stopScan();
    return results
        .map(
          (r) => BleDiscoveredCollar(
            device: r.device,
            name: r.device.platformName.isNotEmpty
                ? r.device.platformName
                : r.advertisementData.advName,
            rssi: r.rssi,
          ),
        )
        .toList();
  }

  Future<void> connect(BluetoothDevice device) async {
    await disconnect();
    _device = device;
    try {
      await device.connect(
        autoConnect: false,
        timeout: const Duration(seconds: 25),
      );
      if (Platform.isAndroid) {
        // MTU negotiation is optional: prepared writes handle smaller packets.
        try {
          await device.requestMtu(512);
        } catch (_) {}
      }
      final services = await device.discoverServices();
      final service = services.firstWhere(
        (s) => s.uuid == Guid(serviceUuid),
        orElse: () =>
            throw const BleException('Harness setup service is missing.'),
      );
      BluetoothCharacteristic characteristic(String uuid) =>
          service.characteristics.firstWhere(
            (c) => c.uuid == Guid(uuid),
            orElse: () => throw const BleException(
              'Update the harness firmware to enable Wi-Fi scanning.',
            ),
          );
      _control = characteristic(controlCharUuid);
      _status = characteristic(statusCharUuid);
      _creds = characteristic(credsCharUuid);
    } catch (_) {
      await disconnect();
      rethrow;
    }
  }

  Future<String> _waitFor(
    bool Function(String) matches,
    Duration timeout,
  ) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      final value = utf8.decode(await _status!.read());
      if (value.startsWith('ERROR:')) throw BleException(value.substring(6));
      if (matches(value)) return value;
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
    throw const BleException(
      'Harness did not respond. Move closer and try again.',
    );
  }

  Future<List<WifiNetwork>> scanNetworks() async {
    if (_control == null) throw const BleException('Select a harness first.');
    await _control!.write(utf8.encode('SCAN'));
    final result = await _waitFor(
      (s) => s.startsWith('SCAN_DONE:'),
      const Duration(seconds: 20),
    );
    final count = int.parse(result.split(':')[1]);
    final networks = <String, WifiNetwork>{};
    for (var i = 0; i < count; i++) {
      await _control!.write(utf8.encode('NETWORK:$i'));
      final response = await _waitFor(
        (s) => s.startsWith('N:$i:'),
        const Duration(seconds: 5),
      );
      final n = WifiNetwork.parse(response);
      if (n.ssid.isNotEmpty &&
          (!networks.containsKey(n.ssid) || n.rssi > networks[n.ssid]!.rssi)) {
        networks[n.ssid] = n;
      }
    }
    return networks.values.toList()..sort((a, b) => b.rssi.compareTo(a.rssi));
  }

  Future<void> sendCredentialsToCollar({
    required BluetoothDevice device,
    required String ssid,
    required String password,
  }) async {
    if (_device?.remoteId != device.remoteId || _creds == null || !device.isConnected) {
      await connect(device);
    }
    await _creds!.write(
      utf8.encode(wifiCredentialsPayload(ssid, password)),
      allowLongWrite: true,
    );
    await _waitFor((s) => s == 'CONNECTED', const Duration(seconds: 25));
  }

  Future<void> stopScan() async {
    if (!kIsWeb) await FlutterBluePlus.stopScan();
  }

  Future<void> disconnect() async {
    final device = _device;
    _device = null;
    _control = null;
    _status = null;
    _creds = null;
    if (device != null) {
      try {
        await device.disconnect();
      } catch (_) {}
    }
  }
}

class BleException implements Exception {
  final String message;
  const BleException(this.message);
  @override
  String toString() => message;
}
