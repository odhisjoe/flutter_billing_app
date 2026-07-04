import 'dart:convert';

import '../../../../core/utils/bluetooth_info.dart';
import '../../../../core/utils/printer_driver.dart';
import '../../../../core/utils/printer_manager.dart';
import '../../../../core/data/hive_database.dart';
import '../../../../core/utils/printer_helper.dart';
import '../../domain/repositories/printer_repository.dart';

class PrinterRepositoryImpl implements PrinterRepository {
  final PrinterHelper _printerHelper = PrinterHelper();
  final PrinterManager _manager = PrinterManager();

  @override
  Future<List<BluetoothInfo>> getBondedDevices() async {
    if (await _printerHelper.checkPermission()) {
      return await _printerHelper.getBondedDevices();
    }
    throw Exception('Bluetooth permission denied');
  }

  @override
  Future<bool> connect(String macAddress) async {
    return await _printerHelper.connect(macAddress);
  }

  @override
  Future<bool> disconnect() async {
    return await _printerHelper.disconnect();
  }

  @override
  String? getSavedPrinterMac() {
    return HiveDatabase.settingsBox.get('printer_mac');
  }

  @override
  String? getSavedPrinterName() {
    return HiveDatabase.settingsBox.get('printer_name');
  }

  @override
  Future<void> savePrinterData(String mac, String name) async {
    await HiveDatabase.settingsBox.put('printer_mac', mac);
    await HiveDatabase.settingsBox.put('printer_name', name);
  }

  @override
  Future<void> clearPrinterData() async {
    await HiveDatabase.settingsBox.delete('printer_mac');
    await HiveDatabase.settingsBox.delete('printer_name');
  }

  @override
  Future<void> testPrint(String shopName) async {
    await _printerHelper
        .printText("Test Print\n\n$shopName\n\n----------------\n\n");
  }

  @override
  Future<List<PrinterDevice>> scanAllDevices() async {
    return _manager.scanAll();
  }

  @override
  Future<bool> connectDevice(PrinterDevice device) async {
    return _manager.connect(device);
  }

  @override
  PrinterDevice? getSavedPrinterDevice() {
    final raw = HiveDatabase.settingsBox.get('printer_device');
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final typeIndex = map['driverType'] as int? ?? 0;
      const safeTypes = PrinterDriverType.values;
      return PrinterDevice(
        name: map['name'] as String? ?? '',
        address: map['address'] as String? ?? '',
        driverType: typeIndex < safeTypes.length ? safeTypes[typeIndex] : PrinterDriverType.usb,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> savePrinterDevice(PrinterDevice device) async {
    final map = {
      'name': device.name,
      'address': device.address,
      'driverType': device.driverType.index,
    };
    await HiveDatabase.settingsBox.put('printer_device', jsonEncode(map));
  }

  @override
  Future<void> clearPrinterDevice() async {
    await HiveDatabase.settingsBox.delete('printer_device');
  }
}
