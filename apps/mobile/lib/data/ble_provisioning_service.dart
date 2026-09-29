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

class BleProvisioningService {
  static const String serviceUuid = '4fafc201-1fb5-459e-8fcc-c5c9c331914b';
  static const String credsCharUuid = 'a3c87500-8ed3-4bdf-8a39-a01bebede295';

  Stream<List<BleDiscoveredCollar>> scanForCollars({Duration timeout = const Duration(seconds: 6)}) async* {
    if (kIsWeb) {
      throw UnsupportedError('Bluetooth provisioning is supported on mobile devices.');
    }

    final isSupported = await FlutterBluePlus.isSupported;
    if (!isSupported) {
      throw const BleException('Bluetooth is not supported on this device.');
    }

    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      if (Platform.isAndroid) {
        await FlutterBluePlus.turnOn();
      } else {
        throw const BleException('Please turn on Bluetooth to connect to the collar.');
      }
    }

    await FlutterBluePlus.startScan(
      withServices: [Guid(serviceUuid)],
      timeout: timeout,
    );

    await for (final results in FlutterBluePlus.scanResults) {
      final collars = <BleDiscoveredCollar>[];
      for (final r in results) {
        final name = r.device.platformName.isNotEmpty
            ? r.device.platformName
            : r.advertisementData.advName;
        if (name.contains('FurFeel') || r.advertisementData.serviceUuids.contains(Guid(serviceUuid))) {
          collars.add(BleDiscoveredCollar(
            device: r.device,
            name: name.isNotEmpty ? name : 'FurFeel Collar (${r.device.remoteId})',
            rssi: r.rssi,
          ));
        }
      }
      yield collars;
    }
  }

  Future<void> sendCredentialsToCollar({
    required BluetoothDevice device,
    required String ssid,
    required String password,
  }) async {
    // 1. Connect
    await device.connect(autoConnect: false).timeout(const Duration(seconds: 10));

    try {
      // Negotiate MTU on Android to allow payloads > 20 bytes
      if (Platform.isAndroid) {
        try {
          await device.requestMtu(512).timeout(const Duration(seconds: 2));
        } catch (_) {}
      }

      // 2. Discover services
      final services = await device.discoverServices();
      final targetService = services.firstWhere(
        (s) => s.uuid == Guid(serviceUuid),
        orElse: () => throw const BleException('FurFeel setup service not found on collar.'),
      );

      final credsChar = targetService.characteristics.firstWhere(
        (c) => c.uuid == Guid(credsCharUuid),
        orElse: () => throw const BleException('Credentials characteristic not found.'),
      );

      // 3. Write SSID;PASSWORD
      final payload = utf8.encode('$ssid;$password');
      if (credsChar.properties.writeWithoutResponse) {
        await credsChar.write(payload, withoutResponse: true);
      } else {
        try {
          await credsChar.write(payload, withoutResponse: false).timeout(const Duration(seconds: 4));
        } catch (_) {
          await credsChar.write(payload, withoutResponse: true);
        }
      }

      // Give ESP32 a moment to process before closing
      await Future<void>.delayed(const Duration(milliseconds: 1000));
    } finally {
      try {
        await device.disconnect();
      } catch (_) {}
    }
  }

  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
  }
}

class BleException implements Exception {
  final String message;
  const BleException(this.message);

  @override
  String toString() => message;
}
