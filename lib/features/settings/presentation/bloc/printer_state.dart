import 'package:equatable/equatable.dart';
import '../../../../core/utils/bluetooth_info.dart';
import '../../../../core/utils/printer_manager.dart';

enum PrinterStatus {
  initial,
  scanning,
  scanSuccess,
  scanFailure,
  connecting,
  connected,
  connectionFailure,
  disconnected,
  testPrinting
}

class PrinterState extends Equatable {
  final PrinterStatus status;
  final String? connectedMac;
  final String? connectedName;
  final List<BluetoothInfo> devices;
  final String? errorMessage;
  final List<PrinterDevice> allDevices;
  final PrinterDevice? connectedDevice;

  const PrinterState({
    this.status = PrinterStatus.initial,
    this.connectedMac,
    this.connectedName,
    this.devices = const [],
    this.errorMessage,
    this.allDevices = const [],
    this.connectedDevice,
  });

  PrinterState copyWith({
    PrinterStatus? status,
    String? connectedMac,
    String? connectedName,
    List<BluetoothInfo>? devices,
    String? errorMessage,
    bool clearError = false,
    List<PrinterDevice>? allDevices,
    PrinterDevice? connectedDevice,
    bool clearConnectedDevice = false,
  }) {
    return PrinterState(
      status: status ?? this.status,
      connectedMac: connectedMac ?? this.connectedMac,
      connectedName: connectedName ?? this.connectedName,
      devices: devices ?? this.devices,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      allDevices: allDevices ?? this.allDevices,
      connectedDevice: clearConnectedDevice ? null : (connectedDevice ?? this.connectedDevice),
    );
  }

  @override
  List<Object?> get props =>
      [status, connectedMac, connectedName, devices, errorMessage, allDevices, connectedDevice];
}
