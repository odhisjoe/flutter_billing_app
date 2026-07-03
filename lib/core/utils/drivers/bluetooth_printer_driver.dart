import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart' as thermal
    if (dart.library.html) '../../web_print_bluetooth_thermal.dart';

import '../bluetooth_info.dart';
import '../printer_driver.dart';

class BluetoothPrinterDriver extends PrinterDriver {
  bool _connected = false;
  String? _currentMac;

  @override
  PrinterDriverType get driverType => PrinterDriverType.bluetooth;

  @override
  bool get isConnected => _connected;

  @override
  String get displayName => _currentMac != null ? 'Bluetooth ($_currentMac)' : 'Bluetooth Printer';

  Future<bool> _checkPermission() async {
    if (kIsWeb) return true;
    final statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();
    return statuses.values.every((s) => s.isGranted);
  }

  @override
  Future<bool> connect(Map<String, dynamic> config) async {
    if (kIsWeb) return false;
    final mac = config['mac'] as String?;
    if (mac == null) return false;

    if (!await _checkPermission()) return false;

    try {
      final result = await thermal.PrintBluetoothThermal
          .connect(macPrinterAddress: mac);
      _connected = result;
      if (result) _currentMac = mac;
      return result;
    } catch (e) {
      _connected = false;
      return false;
    }
  }

  @override
  Future<bool> disconnect() async {
    if (kIsWeb) return true;
    try {
      await thermal.PrintBluetoothThermal.disconnect;
      _connected = false;
      _currentMac = null;
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> writeBytes(List<int> bytes) async {
    if (kIsWeb || !_connected) return;
    await thermal.PrintBluetoothThermal.writeBytes(bytes);
  }

  @override
  Future<void> writeText(String text) async {
    await writeBytes(List.from(text.codeUnits));
  }

  @override
  Future<List<BluetoothInfo>> getAvailableDevices() async {
    if (kIsWeb) return [];
    if (!await _checkPermission()) return [];
    try {
      final devices = await thermal.PrintBluetoothThermal.pairedBluetooths;
      return devices.map((d) => BluetoothInfo(
            name: d.name,
            macAdress: d.macAdress,
          )).toList();
    } catch (e) {
      return [];
    }
  }
}
