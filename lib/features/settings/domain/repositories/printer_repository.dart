import '../../../../core/utils/bluetooth_info.dart';
import '../../../../core/utils/printer_manager.dart';

abstract class PrinterRepository {
  Future<List<BluetoothInfo>> getBondedDevices();
  Future<bool> connect(String macAddress);
  Future<bool> disconnect();
  String? getSavedPrinterMac();
  String? getSavedPrinterName();
  Future<void> savePrinterData(String mac, String name);
  Future<void> clearPrinterData();
  Future<void> testPrint(String shopName);

  // Multi-printer support
  Future<List<PrinterDevice>> scanAllDevices();
  Future<bool> connectDevice(PrinterDevice device);
  PrinterDevice? getSavedPrinterDevice();
  Future<void> savePrinterDevice(PrinterDevice device);
  Future<void> clearPrinterDevice();
}
