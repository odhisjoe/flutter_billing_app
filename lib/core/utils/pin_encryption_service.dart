import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../data/hive_database.dart';

class PinEncryptionService {
  static const _secureKey = 'pin_encryption_key';
  static const _hiveKey = 'pin_encryption_key';
  final FlutterSecureStorage _secureStorage;
  encrypt.Key? _key;

  PinEncryptionService({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  Future<void> initialize() async {
    String? storedKey;

    try {
      storedKey = await _secureStorage.read(key: _secureKey);
    } catch (_) {}

    if (storedKey == null || storedKey.isEmpty) {
      try {
        storedKey = HiveDatabase.settingsBox.get(_hiveKey) as String?;
      } catch (_) {}
    }

    if (storedKey != null && storedKey.isNotEmpty) {
      _key = encrypt.Key(base64.decode(storedKey));
      return;
    }

    _key = encrypt.Key.fromSecureRandom(32);
    final encoded = base64.encode(_key!.bytes);

    try {
      await _secureStorage.write(key: _secureKey, value: encoded);
    } catch (_) {}

    try {
      await HiveDatabase.settingsBox.put(_hiveKey, encoded);
    } catch (_) {}
  }

  String encryptPin(String pin) {
    _ensureInitialized();
    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(_key!));
    final encrypted = encrypter.encrypt(pin, iv: iv);
    return '${base64.encode(iv.bytes)}:${encrypted.base64}';
  }

  String decryptPin(String encryptedPin) {
    _ensureInitialized();
    final parts = encryptedPin.split(':');
    if (parts.length != 2) {
      throw FormatException('Not a valid encrypted PIN');
    }
    final iv = encrypt.IV(base64.decode(parts[0]));
    final encrypter = encrypt.Encrypter(encrypt.AES(_key!));
    return encrypter.decrypt64(parts[1], iv: iv);
  }

  bool verify(String pin, String encryptedPin) {
    try {
      return decryptPin(encryptedPin) == pin;
    } catch (_) {
      return false;
    }
  }

  void _ensureInitialized() {
    if (_key != null) return;
    _key = encrypt.Key(
      Uint8List.fromList(List.generate(32, (_) => Random().nextInt(256))),
    );
  }
}