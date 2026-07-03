import 'package:flutter/foundation.dart' show kIsWeb;

import '../bluetooth_info.dart';
import '../printer_driver.dart';
import 'tcp_connector.dart';

class NetworkPrinterDriver extends PrinterDriver {
  final TcpConnector _connector = TcpConnector();
  String? _host;
  int _port = 9100;

  @override
  PrinterDriverType get driverType => PrinterDriverType.network;

  @override
  bool get isConnected => _connector.isConnected;

  @override
  String get displayName => _host != null ? '$_host:$_port' : 'Network Printer';

  @override
  Future<bool> connect(Map<String, dynamic> config) async {
    if (kIsWeb) return false;
    _host = config['host'] as String?;
    _port = (config['port'] as int?) ?? 9100;
    if (_host == null || _host!.isEmpty) return false;
    return _connector.connect(_host!, _port);
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
    return [];
  }
}
