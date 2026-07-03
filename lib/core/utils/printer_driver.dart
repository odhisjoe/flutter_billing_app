import 'bluetooth_info.dart';

enum PrinterDriverType { bluetooth, usb, network, windowsUsb, windowsBluetooth }

abstract class PrinterDriver {
  PrinterDriverType get driverType;
  bool get isConnected;
  String get displayName;

  Future<bool> connect(Map<String, dynamic> config);
  Future<bool> disconnect();
  Future<void> writeBytes(List<int> bytes);
  Future<void> writeText(String text);
  Future<List<BluetoothInfo>> getAvailableDevices();
}
