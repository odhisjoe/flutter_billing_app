import 'package:equatable/equatable.dart';
import '../../../../core/utils/printer_manager.dart';

abstract class PrinterEvent extends Equatable {
  const PrinterEvent();

  @override
  List<Object?> get props => [];
}

class InitPrinterEvent extends PrinterEvent {}

class RefreshPrinterEvent extends PrinterEvent {}

class ScanPrintersEvent extends PrinterEvent {}

class ConnectPrinterEvent extends PrinterEvent {
  final String mac;
  final String name;

  const ConnectPrinterEvent({required this.mac, required this.name});

  @override
  List<Object?> get props => [mac, name];
}

class DisconnectPrinterEvent extends PrinterEvent {}

class TestPrintEvent extends PrinterEvent {
  final String shopName;

  const TestPrintEvent(this.shopName);

  @override
  List<Object?> get props => [shopName];
}

class ScanAllDevicesEvent extends PrinterEvent {}

class ConnectToDeviceEvent extends PrinterEvent {
  final PrinterDevice device;

  const ConnectToDeviceEvent(this.device);

  @override
  List<Object?> get props => [device];
}
