import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/printer_repository.dart';
import 'printer_event.dart';
import 'printer_state.dart';

class PrinterBloc extends Bloc<PrinterEvent, PrinterState> {
  final PrinterRepository repository;

  PrinterBloc({required this.repository}) : super(const PrinterState()) {
    on<InitPrinterEvent>(_onInit);
    on<RefreshPrinterEvent>(_onRefresh);
    on<ScanPrintersEvent>(_onScan);
    on<ConnectPrinterEvent>(_onConnect);
    on<DisconnectPrinterEvent>(_onDisconnect);
    on<TestPrintEvent>(_onTestPrint);
    on<ScanAllDevicesEvent>(_onScanAll);
    on<ConnectToDeviceEvent>(_onConnectDevice);
  }

  void _onInit(InitPrinterEvent event, Emitter<PrinterState> emit) {
    final mac = repository.getSavedPrinterMac();
    final name = repository.getSavedPrinterName();
    final savedDevice = repository.getSavedPrinterDevice();
    emit(state.copyWith(
      status: PrinterStatus.initial,
      connectedMac: mac,
      connectedName: name,
      connectedDevice: savedDevice,
    ));
  }

  Future<void> _onRefresh(
      RefreshPrinterEvent event, Emitter<PrinterState> emit) async {
    emit(state.copyWith(status: PrinterStatus.scanning, clearError: true));
    try {
      final devices = await repository.getBondedDevices();
      if (devices.isEmpty) {
        emit(state.copyWith(
          status: PrinterStatus.scanFailure,
          errorMessage: 'No paired devices found.',
          devices: [],
        ));
        return;
      }

      bool connected = false;
      for (var device in devices) {
        final success = await repository.connect(device.macAddress);
        if (success) {
          await repository.savePrinterData(device.macAddress, device.name);
          emit(state.copyWith(
            status: PrinterStatus.connected,
            connectedMac: device.macAddress,
            connectedName: device.name,
            devices: devices,
            clearError: true,
          ));
          connected = true;
          break;
        }
      }

      if (!connected) {
        emit(state.copyWith(
          status: PrinterStatus.scanFailure,
          errorMessage: 'Could not connect to any paired device.',
          devices: devices,
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        status: PrinterStatus.scanFailure,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onScan(
      ScanPrintersEvent event, Emitter<PrinterState> emit) async {
    emit(state.copyWith(status: PrinterStatus.scanning, clearError: true));
    try {
      final devices = await repository.getBondedDevices();
      emit(state.copyWith(
        status: PrinterStatus.scanSuccess,
        devices: devices,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: PrinterStatus.scanFailure,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onConnect(
      ConnectPrinterEvent event, Emitter<PrinterState> emit) async {
    emit(state.copyWith(status: PrinterStatus.connecting, clearError: true));
    final success = await repository.connect(event.mac);
    if (success) {
      await repository.savePrinterData(event.mac, event.name);
      emit(state.copyWith(
        status: PrinterStatus.connected,
        connectedMac: event.mac,
        connectedName: event.name,
      ));
    } else {
      emit(state.copyWith(
        status: PrinterStatus.connectionFailure,
        errorMessage: 'Failed to connect to printer',
      ));
    }
  }

  Future<void> _onDisconnect(
      DisconnectPrinterEvent event, Emitter<PrinterState> emit) async {
    await repository.disconnect();
    await repository.clearPrinterData();
    await repository.clearPrinterDevice();
    emit(PrinterState(
      status: PrinterStatus.disconnected,
      devices: state.devices,
    ));
  }

  Future<void> _onTestPrint(
      TestPrintEvent event, Emitter<PrinterState> emit) async {
    emit(state.copyWith(status: PrinterStatus.testPrinting));
    await repository.testPrint(event.shopName);
    emit(state.copyWith(status: PrinterStatus.scanSuccess));
  }

  Future<void> _onScanAll(
      ScanAllDevicesEvent event, Emitter<PrinterState> emit) async {
    emit(state.copyWith(status: PrinterStatus.scanning, clearError: true));
    try {
      final allDevices = await repository.scanAllDevices();
      emit(state.copyWith(
        status: PrinterStatus.scanSuccess,
        allDevices: allDevices,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: PrinterStatus.scanFailure,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onConnectDevice(
      ConnectToDeviceEvent event, Emitter<PrinterState> emit) async {
    emit(state.copyWith(status: PrinterStatus.connecting, clearError: true));
    final success = await repository.connectDevice(event.device);
    if (success) {
      await repository.savePrinterDevice(event.device);
      emit(state.copyWith(
        status: PrinterStatus.connected,
        connectedDevice: event.device,
        connectedMac: event.device.address,
        connectedName: event.device.name,
      ));
    } else {
      emit(state.copyWith(
        status: PrinterStatus.connectionFailure,
        errorMessage: 'Failed to connect to ${event.device.name}',
      ));
    }
  }
}
