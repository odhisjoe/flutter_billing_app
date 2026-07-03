import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

import 'printer_driver.dart';
import 'printer_helper.dart';
import 'print_platform.dart'
    if (dart.library.html) 'print_platform_web.dart';
import 'drivers/bluetooth_printer_driver.dart';
import 'drivers/network_printer_driver.dart';
import 'drivers/usb_printer_driver.dart';
import 'drivers/windows_usb_driver.dart';
import 'drivers/windows_bt_driver.dart';

class PrinterManager {
  static final PrinterManager _instance = PrinterManager._internal();
  factory PrinterManager() => _instance;
  PrinterManager._internal();

  final BluetoothPrinterDriver _bluetooth = BluetoothPrinterDriver();
  final NetworkPrinterDriver _network = NetworkPrinterDriver();
  final UsbPrinterDriver _usb = UsbPrinterDriver();
  final WindowsUsbDriver _windowsUsb = WindowsUsbDriver();
  final WindowsBtDriver _windowsBt = WindowsBtDriver();

  PrinterDriver? _selectedDriver;

  PrinterDriver? get selectedDriver => _selectedDriver;
  bool get isConnected => _selectedDriver?.isConnected ?? false;

  List<PrinterDriver> get allDrivers {
    final drivers = <PrinterDriver>[_bluetooth, _network, _usb];
    if (!kIsWeb && Platform.isWindows) {
      drivers.addAll([_windowsUsb, _windowsBt]);
    }
    return drivers;
  }

  Future<List<PrinterDevice>> scanAll() async {
    final devices = <PrinterDevice>[];
    for (final driver in allDrivers) {
      final found = await driver.getAvailableDevices();
      for (final d in found) {
        devices.add(PrinterDevice(
          name: d.name,
          address: d.macAddress,
          driverType: driver.driverType,
        ));
      }
    }
    return devices;
  }

  Future<bool> connect(PrinterDevice device) async {
    PrinterDriver? driver;
    switch (device.driverType) {
      case PrinterDriverType.bluetooth:
        driver = _bluetooth;
        break;
      case PrinterDriverType.usb:
        driver = _usb;
        break;
      case PrinterDriverType.network:
        driver = _network;
        break;
      case PrinterDriverType.windowsUsb:
        driver = _windowsUsb;
        break;
      case PrinterDriverType.windowsBluetooth:
        driver = _windowsBt;
        break;
    }
    final config = <String, dynamic>{};
    switch (device.driverType) {
      case PrinterDriverType.bluetooth:
        config['mac'] = device.address;
        break;
      case PrinterDriverType.usb:
        config['port'] = device.address;
        break;
      case PrinterDriverType.network:
        final parts = device.address.split(':');
        config['host'] = parts[0];
        config['port'] = parts.length > 1 ? int.tryParse(parts[1]) ?? 9100 : 9100;
        break;
      case PrinterDriverType.windowsUsb:
        config['printerName'] = device.address;
        break;
      case PrinterDriverType.windowsBluetooth:
        config['address'] = device.address;
        config['name'] = device.name;
        break;
    }

    final success = await driver.connect(config);
    if (success) _selectedDriver = driver;
    return success;
  }

  Future<bool> disconnect() async {
    if (_selectedDriver == null) return true;
    final result = await _selectedDriver!.disconnect();
    _selectedDriver = null;
    return result;
  }

  Future<void> writeBytes(List<int> bytes) async {
    if (_selectedDriver == null) return;
    await _selectedDriver!.writeBytes(bytes);
  }

  Future<void> writeText(String text) async {
    if (_selectedDriver == null) return;
    await _selectedDriver!.writeText(text);
  }

  Future<void> printReceipt({
    required String shopName,
    required String address1,
    required String address2,
    required String phone,
    required List<Map<String, dynamic>> items,
    required double total,
    required double vatRate,
    required double vatAmount,
    required String kraPin,
    required String footer,
    Map<String, dynamic>? payment,
  }) async {
    final receiptText = PrinterHelper.buildReceiptText(
      shopName: shopName,
      address1: address1,
      address2: address2,
      phone: phone,
      items: items,
      total: total,
      vatRate: vatRate,
      vatAmount: vatAmount,
      kraPin: kraPin,
      footer: footer,
      payment: payment,
    );

    if (kIsWeb) {
      browserPrint(receiptText);
      return;
    }

    List<int> bytes = [];
    bytes += EscPos.init;
    bytes += List.from(receiptText.codeUnits);
    bytes += EscPos.lineFeed;

    await writeBytes(bytes);
  }
}

class PrinterDevice {
  final String name;
  final String address;
  final PrinterDriverType driverType;

  const PrinterDevice({
    required this.name,
    required this.address,
    required this.driverType,
  });

  String get displayType {
    switch (driverType) {
      case PrinterDriverType.bluetooth:
        return 'Bluetooth';
      case PrinterDriverType.usb:
        return 'USB (COM)';
      case PrinterDriverType.network:
        return 'Network';
      case PrinterDriverType.windowsUsb:
        return 'Windows USB';
      case PrinterDriverType.windowsBluetooth:
        return 'Windows BT';
    }
  }

  @override
  String toString() => '$name ($displayType)';
}
