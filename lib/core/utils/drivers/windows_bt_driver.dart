import '../bluetooth_info.dart';
import '../printer_driver.dart';
import 'windows_bt_connector.dart';

class WindowsBtDriver extends PrinterDriver {
  final WindowsBtConnector _connector = WindowsBtConnector();
  String? _deviceAddress;
  String? _deviceName;

  @override
  PrinterDriverType get driverType => PrinterDriverType.windowsBluetooth;

  @override
  bool get isConnected => _connector.isConnected;

  @override
  String get displayName =>
      _deviceName != null ? 'Windows BT ($_deviceName)' : 'Windows Bluetooth';

  @override
  Future<bool> connect(Map<String, dynamic> config) async {
    _deviceAddress = config['address'] as String?;
    _deviceName = config['name'] as String?;
    if (_deviceAddress == null || _deviceAddress!.isEmpty) return false;
    return _connector.connect(_deviceAddress!);
  }

  @override
  Future<bool> disconnect() async {
    return _connector.disconnect();
  }

  @override
  Future<void> writeBytes(List<int> bytes) async {
    await _connector.writeRaw(bytes);
  }

  @override
  Future<void> writeText(String text) async {
    await writeBytes(List.from(text.codeUnits));
  }

  @override
  Future<List<BluetoothInfo>> getAvailableDevices() async {
    final printers = await _connector.getAvailablePrinters();
    return printers
        .map((p) => BluetoothInfo(
              name: p['name'] ?? p['address'] ?? '',
              macAdress: p['address'] ?? '',
            ))
        .toList();
  }
}
