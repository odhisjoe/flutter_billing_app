import '../bluetooth_info.dart';
import '../printer_driver.dart';
import 'windows_usb_connector.dart';

class WindowsUsbDriver extends PrinterDriver {
  final WindowsUsbConnector _connector = WindowsUsbConnector();
  String? _printerName;

  @override
  PrinterDriverType get driverType => PrinterDriverType.windowsUsb;

  @override
  bool get isConnected => _connector.isConnected;

  @override
  String get displayName =>
      _printerName != null ? 'Windows ($_printerName)' : 'Windows Printer';

  @override
  Future<bool> connect(Map<String, dynamic> config) async {
    _printerName = config['printerName'] as String?;
    if (_printerName == null || _printerName!.isEmpty) return false;
    return _connector.connect(_printerName!);
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
        .map((p) => BluetoothInfo(name: p, macAdress: p))
        .toList();
  }
}
