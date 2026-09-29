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
  static const String scanCharUuid = 'beb5483e-36e1-4688-b7f5-ea07361b26a8';
  static const String credsCharUuid = 'a3c87500-8ed3-4bdf-8a39-a01bebede295';
  static const String statusCharUuid = 'cba1d466-344c-4be3-ab3f-189f80dd7518';

  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _scanChar;
  BluetoothCharacteristic? _credsChar;
  BluetoothCharacteristic? _statusChar;

  Stream<List<BleDiscoveredCollar>> scanForCollars({Duration timeout = const Duration(seconds: 8)}) async* {
    if (kIsWeb) {
      throw UnsupportedError('Bluetooth provisioning is supported on mobile devices.');
    }

    final isSupported = await FlutterBluePlus.isSupported;
    if (!isSupported) {
      throw const BleException('Bluetooth is not supported on this device.');
    }

    // Check adapter state
    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      if (Platform.isAndroid) {
        await FlutterBluePlus.turnOn();
      } else {
        throw const BleException('Please turn on Bluetooth to connect to the collar.');
      }
    }

    // Start scan
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
        // Accept FurFeel collars or matching service UUID
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

  Future<void> connectToCollar(BluetoothDevice device) async {
    _connectedDevice = device;
    await device.connect(autoConnect: false).timeout(const Duration(seconds: 10));

    if (Platform.isAndroid) {
      try {
        await device.requestMtu(512);
      } catch (_) {}
    }

    final services = await device.discoverServices();
    final targetService = services.firstWhere(
      (s) => s.uuid == Guid(serviceUuid),
      orElse: () => throw const BleException('FurFeel Provisioning Service not found on device.'),
    );

    for (final c in targetService.characteristics) {
      if (c.uuid == Guid(scanCharUuid)) _scanChar = c;
      if (c.uuid == Guid(credsCharUuid)) _credsChar = c;
      if (c.uuid == Guid(statusCharUuid)) _statusChar = c;
    }

    if (_credsChar == null || _statusChar == null) {
      throw const BleException('Incompatible collar firmware: missing characteristics.');
    }
  }

  Future<List<String>> requestWifiScan() async {
    if (_scanChar == null) {
      throw const BleException('Collar is not connected.');
    }

    final completer = Completer<String>();
    StreamSubscription<List<int>>? sub;

    try {
      await _scanChar!.setNotifyValue(true);
      sub = _scanChar!.lastValueStream.listen((value) {
        if (value.isNotEmpty) {
          final text = utf8.decode(value, allowMalformed: true);
          if (!completer.isCompleted && text.isNotEmpty) {
            completer.complete(text);
          }
        }
      });

      // Send SCAN command
      await _scanChar!.write(utf8.encode('SCAN'), withoutResponse: false);

      final rawResult = await completer.future.timeout(
        const Duration(seconds: 8),
        onTimeout: () => '',
      );

      if (rawResult.isEmpty || rawResult == 'NO_NETWORKS') {
        return [];
      }

      return rawResult
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    } finally {
      await sub?.cancel();
    }
  }

  Future<String> sendWifiCredentials(String ssid, String password) async {
    if (_credsChar == null || _statusChar == null) {
      throw const BleException('Collar is not connected.');
    }

    final completer = Completer<String>();
    StreamSubscription<List<int>>? sub;

    try {
      await _statusChar!.setNotifyValue(true);
      sub = _statusChar!.lastValueStream.listen((value) {
        if (value.isNotEmpty) {
          final status = utf8.decode(value, allowMalformed: true);
          if (!completer.isCompleted) {
            completer.complete(status);
          }
        }
      });

      // Format: SSID;PASSWORD
      final payload = utf8.encode('$ssid;$password');
      await _credsChar!.write(payload, withoutResponse: false);

      // Wait for connection confirmation from ESP32 (up to 15s)
      final status = await completer.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () => 'TIMEOUT',
      );

      return status;
    } finally {
      await sub?.cancel();
    }
  }

  Future<void> disconnect() async {
    try {
      await _connectedDevice?.disconnect();
    } catch (_) {}
    _connectedDevice = null;
    _scanChar = null;
    _credsChar = null;
    _statusChar = null;
  }
}

class BleException implements Exception {
  final String message;
  const BleException(this.message);

  @override
  String toString() => message;
}
