class WindowsUsbConnector {
  bool get isConnected => false;

  Future<bool> connect(String printerName) async => false;

  Future<bool> disconnect() async => true;

  Future<bool> writeRaw(List<int> bytes) async => false;

  Future<List<String>> getAvailablePrinters() async => [];
}
