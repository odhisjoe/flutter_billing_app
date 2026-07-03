import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

class BarcodeScannerService {
  static final BarcodeScannerService _instance = BarcodeScannerService._();
  factory BarcodeScannerService() => _instance;
  BarcodeScannerService._();

  final StreamController<String> _controller = StreamController<String>.broadcast();
  Stream<String> get onBarcodeScanned => _controller.stream;

  final StringBuffer _buffer = StringBuffer();
  DateTime _lastKeyTime = DateTime.now();
  Timer? _resetTimer;
  bool _initialized = false;

  static const _scannerInterval = Duration(milliseconds: 50);
  static const _timeout = Duration(milliseconds: 300);

  void initialize() {
    if (_initialized || kIsWeb || !Platform.isWindows) return;
    _initialized = true;
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    final now = DateTime.now();
    final interval = now.difference(_lastKeyTime);
    _lastKeyTime = now;

    if (interval > _scannerInterval && _buffer.isNotEmpty) {
      _buffer.clear();
    }

    if (event.logicalKey == LogicalKeyboardKey.enter) {
      final barcode = _buffer.toString().trim();
      if (barcode.isNotEmpty) {
        _controller.add(barcode);
      }
      _buffer.clear();
      _resetTimer?.cancel();
      return false;
    }

    final char = event.character;
    if (char != null && char.isNotEmpty) {
      _buffer.write(char);
      _resetTimer?.cancel();
      _resetTimer = Timer(_timeout, () => _buffer.clear());
    }

    return false;
  }

  void dispose() {
    if (_initialized) {
      HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    }
    _resetTimer?.cancel();
    _controller.close();
  }
}
