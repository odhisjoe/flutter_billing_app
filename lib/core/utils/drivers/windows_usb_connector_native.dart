import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:windows_printer/windows_printer.dart';

class WindowsUsbConnector {
  String? _printerName;
  bool _connected = false;

  bool get isConnected => _connected;

  Future<bool> connect(String printerName) async {
    if (!Platform.isWindows) return false;
    _printerName = printerName;
    _connected = true;
    return true;
  }

  Future<bool> disconnect() async {
    _printerName = null;
    _connected = false;
    return true;
  }

  Future<bool> writeRaw(List<int> bytes) async {
    if (!Platform.isWindows || _printerName == null) return false;
    try {
      await WindowsPrinter.printRawData(
        printerName: _printerName,
        data: Uint8List.fromList(bytes),
        useRawDatatype: true,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<String>> getAvailablePrinters() async {
    if (!Platform.isWindows) return [];
    try {
      final printers = await WindowsPrinter.getAvailablePrinters();
      return printers;
    } catch (_) {
      return [];
    }
  }
}
