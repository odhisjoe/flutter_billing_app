import 'dart:io';

class TcpConnector {
  Socket? _socket;

  bool get isConnected => _socket != null;

  Future<bool> connect(String host, int port) async {
    try {
      _socket = await Socket.connect(host, port,
          timeout: const Duration(seconds: 5));
      return true;
    } catch (_) {
      _socket = null;
      return false;
    }
  }

  void write(List<int> bytes) {
    _socket?.add(bytes);
  }

  Future<void> flush() async {
    await _socket?.flush();
  }

  Future<void> disconnect() async {
    try {
      await _socket?.close();
    } catch (_) {}
    _socket = null;
  }
}
