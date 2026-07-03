class WindowsBtConnector {
  bool get isConnected => false;

  Future<bool> connect(String address) async => false;

  Future<bool> disconnect() async => true;

  Future<bool> writeRaw(List<int> bytes) async => false;

  Future<List<Map<String, String>>> getAvailablePrinters() async => [];
}
