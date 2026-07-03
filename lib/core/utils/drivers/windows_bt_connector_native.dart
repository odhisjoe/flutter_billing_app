import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:flutter_thermal_printer_windows/flutter_thermal_printer_windows.dart';

class WindowsBtConnector {
  BluetoothPrinter? _device;
  final ThermalPrinterWindows _api = ThermalPrinterWindows.instance;

  bool get isConnected => _device != null;

  Future<bool> connect(String macAddress) async {
    if (!Platform.isWindows) return false;
    try {
      final printers = await _api.getPairedPrinters();
      final match = printers.where((p) => p.macAddress == macAddress).firstOrNull;
      if (match == null) return false;
      await _api.connect(match);
      _device = match;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> disconnect() async {
    if (_device == null || !Platform.isWindows) return true;
    try {
      await _api.disconnect(_device!);
      _device = null;
      return true;
    } catch (_) {
      _device = null;
      return true;
    }
  }

  Future<bool> writeRaw(List<int> bytes) async {
    if (_device == null || !Platform.isWindows) return false;
    try {
      await _api.printRawBytes(_device!, Uint8List.fromList(bytes));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, String>>> getAvailablePrinters() async {
    if (!Platform.isWindows) return [];
    try {
      final printers = await _api.scanForPrinters(timeout: const Duration(seconds: 15));
      return printers.map((p) => {
        'name': p.name,
        'address': p.macAddress,
      }).toList();
    } catch (_) {
      return [];
    }
  }
}
