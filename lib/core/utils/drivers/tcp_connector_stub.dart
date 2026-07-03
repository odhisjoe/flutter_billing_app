class TcpConnector {
  bool get isConnected => false;

  Future<bool> connect(String host, int port) async => false;

  void write(List<int> bytes) {}

  Future<void> flush() async {}

  Future<void> disconnect() async {}
}
