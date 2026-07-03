import 'package:flutter/foundation.dart' show kIsWeb;

import '../bluetooth_info.dart';
import '../printer_driver.dart';
import 'serial_connector.dart';

class UsbPrinterDriver extends PrinterDriver {
  final SerialConnector _connector = SerialConnector();
  String? _portName;

  @override
  PrinterDriverType get driverType => PrinterDriverType.usb;

  @override
  bool get isConnected => _connector.isConnected;

  @override
  String get displayName => _portName != null ? 'USB ($_portName)' : 'USB Printer';

  @override
  Future<bool> connect(Map<String, dynamic> config) async {
    if (kIsWeb) return false;
    _portName = config['port'] as String?;
    if (_portName == null || _portName!.isEmpty) return false;
    return _connector.connect(_portName!);
  }

  @override
  Future<bool> disconnect() async {
    await _connector.disconnect();
    return true;
  }

  @override
  Future<void> writeBytes(List<int> bytes) async {
    _connector.write(bytes);
    await _connector.flush();
  }

  @override
  Future<void> writeText(String text) async {
    await writeBytes(List.from(text.codeUnits));
  }

  @override
  Future<List<BluetoothInfo>> getAvailableDevices() async {
    final ports = await _connector.scanPorts();
    return ports
        .map((p) => BluetoothInfo(name: 'USB ($p)', macAdress: p))
        .toList();
  }
}
