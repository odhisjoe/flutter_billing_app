import 'bluetooth_info.dart';

// Stub for web implementation to avoid compilation errors.
class PrintBluetoothThermal {
  static Future<List<BluetoothInfo>> get pairedBluetooths async => [];
  static Stream<BluetoothInfo> scan({required Duration timeout}) async* {}
  static Future<bool> connect({required String macPrinterAddress}) async => false;
  static Future<bool> get disconnect async => true;
  static Future<bool> get connectionStatus async => false;
  static Future<void> writeBytes(List<int> bytes) async {}
}
