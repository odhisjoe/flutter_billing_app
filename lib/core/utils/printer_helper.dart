import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import 'bluetooth_info.dart';
import 'printer_driver.dart';
import 'printer_manager.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart' as thermal
    if (dart.library.html) 'web_print_bluetooth_thermal.dart';

class EscPos {
  static const List<int> init = [0x1B, 0x40];
  static const List<int> alignCenter = [0x1B, 0x61, 0x01];
  static const List<int> alignLeft = [0x1B, 0x61, 0x00];
  static const List<int> alignRight = [0x1B, 0x61, 0x02];
  static const List<int> boldOn = [0x1B, 0x45, 0x01];
  static const List<int> boldOff = [0x1B, 0x45, 0x00];
  static const List<int> textNormal = [0x1D, 0x21, 0x00];
  static const List<int> textLarge = [0x1D, 0x21, 0x11];
  static const List<int> lineFeed = [0x0A];
}

class PrinterHelper {
  static final PrinterHelper _instance = PrinterHelper._internal();
  factory PrinterHelper() => _instance;
  PrinterHelper._internal();

  final PrinterManager _manager = PrinterManager();

  bool get isConnected => _manager.isConnected;

  Future<bool> checkPermission() async {
    if (kIsWeb) return true;
    final Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();
    return statuses.values.every((status) => status.isGranted);
  }

  Future<List<BluetoothInfo>> getBondedDevices() async {
    if (kIsWeb) return [];
    try {
      final devices = await thermal.PrintBluetoothThermal.pairedBluetooths;
      return devices.map((d) => BluetoothInfo(
            name: d.name,
            macAdress: d.macAdress,
          )).toList();
    } catch (e) {
      return [];
    }
  }

  Future<bool> connect(String macAddress) async {
    return _manager.connect(PrinterDevice(
      name: 'Bluetooth',
      address: macAddress,
      driverType: PrinterDriverType.bluetooth,
    ));
  }

  Future<bool> disconnect() async {
    return _manager.disconnect();
  }

  Future<void> printText(String text) async {
    await _manager.writeText(text);
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
    await _manager.printReceipt(
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
  }

  static String buildReceiptText({
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
  }) {
    final buf = StringBuffer();
    buf.writeln(shopName);
    if (address1.isNotEmpty) buf.writeln(address1);
    if (address2.isNotEmpty) buf.writeln(address2);
    buf.writeln(phone);
    if (kraPin.isNotEmpty) buf.writeln('KRA PIN: $kraPin');
    buf.writeln(DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.now()));
    buf.writeln('================================');
    buf.writeln('Item            Price   Total');
    buf.writeln('--------------------------------');

    for (var item in items) {
      String name = item['name'].toString();
      String qty = item['qty'].toString();
      String price = 'KES ${item['price']}';
      String totalItem = 'KES ${item['total']}';
      String prefix = '${qty}x $name';
      if (prefix.length > 16) prefix = prefix.substring(0, 16);
      String line = prefix.padRight(16) + price.padRight(10) + totalItem;
      buf.writeln(line);
    }

    buf.writeln('--------------------------------');
    if (vatRate > 0) {
      buf.writeln('Subtotal: KES ${total.toStringAsFixed(2)}');
      buf.writeln('VAT ($vatRate%): KES ${vatAmount.toStringAsFixed(2)}');
      final grandTotal = total + vatAmount;
      buf.writeln('TOTAL: KES ${grandTotal.toStringAsFixed(2)}');
    } else {
      buf.writeln('TOTAL: KES ${total.toStringAsFixed(2)}');
    }

    if (payment != null) {
      buf.writeln('--------------------------------');
      buf.writeln('PAYMENT');
      if ((payment['cash'] ?? 0) > 0) {
        buf.writeln('Cash: KES ${(payment['cash'] as double).toStringAsFixed(2)}');
      }
      if ((payment['mpesa'] ?? 0) > 0) {
        buf.writeln('M-Pesa: KES ${(payment['mpesa'] as double).toStringAsFixed(2)}');
      }
      if ((payment['card'] ?? 0) > 0) {
        buf.writeln('Card: KES ${(payment['card'] as double).toStringAsFixed(2)}');
      }
      if ((payment['bank'] ?? 0) > 0) {
        buf.writeln('Bank: KES ${(payment['bank'] as double).toStringAsFixed(2)}');
      }
      if ((payment['change'] ?? 0) > 0) {
        buf.writeln('Change: KES ${(payment['change'] as double).toStringAsFixed(2)}');
      }
    }

    buf.writeln('');
    buf.writeln(footer);

    return buf.toString();
  }
}
