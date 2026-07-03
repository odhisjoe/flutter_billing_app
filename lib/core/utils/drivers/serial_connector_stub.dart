class SerialConnector {
  bool get isConnected => false;

  Future<bool> connect(String portName) async => false;

  void write(List<int> bytes) {}

  Future<void> flush() async {}

  Future<void> disconnect() async {}

  Future<List<String>> scanPorts() async => [];
}
