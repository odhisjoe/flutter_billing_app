import 'dart:io';

class SerialConnector {
  RandomAccessFile? _port;

  bool get isConnected => _port != null;

  Future<bool> connect(String portName) async {
    try {
      if (Platform.isWindows && !portName.startsWith('\\\\.\\')) {
        portName = '\\\\.\\$portName';
      }
      final file = File(portName);
      _port = await file.open(mode: FileMode.write);
      return true;
    } catch (e) {
      _port = null;
      return false;
    }
  }

  void write(List<int> bytes) {
    _port?.writeFromSync(bytes);
  }

  Future<void> flush() async {
    _port?.flushSync();
  }

  Future<void> disconnect() async {
    try {
      await _port?.close();
    } catch (_) {}
    _port = null;
  }

  Future<List<String>> scanPorts() async {
    final ports = <String>[];
    if (Platform.isWindows) {
      for (int i = 1; i <= 16; i++) {
        ports.add('COM$i');
      }
    } else if (Platform.isLinux) {
      for (int i = 0; i <= 4; i++) {
        ports.add('/dev/ttyUSB$i');
        ports.add('/dev/ttyACM$i');
      }
    }
    final available = <String>[];
    for (final port in ports) {
      try {
        final path = Platform.isWindows ? '\\\\.\\$port' : port;
        final f = File(path);
        final raf = await f.open(mode: FileMode.write);
        await raf.close();
        available.add(port);
      } catch (_) {}
    }
    return available;
  }
}
