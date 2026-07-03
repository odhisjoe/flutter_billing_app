import 'dart:convert';
import 'package:crypto/crypto.dart';

enum PinHashVersion { legacy, sha256 }

class PinHashUtils {
  static const int versionLegacy = 1;
  static const int versionSha256 = 2;

  static String hash(String pin, {PinHashVersion version = PinHashVersion.sha256}) {
    switch (version) {
      case PinHashVersion.legacy:
        return _legacyHash(pin);
      case PinHashVersion.sha256:
        return _sha256Hash(pin);
    }
  }

  static String _legacyHash(String pin) {
    final bytes = utf8.encode(pin);
    return base64.encode(bytes);
  }

  static String _sha256Hash(String pin) {
    final bytes = utf8.encode(pin);
    return sha256.convert(bytes).toString();
  }

  static bool verify(String pin, String storedHash, int version) {
    if (version == versionLegacy) {
      return _legacyHash(pin) == storedHash;
    }
    return _sha256Hash(pin) == storedHash;
  }

  static String migrateHash(String pin, int fromVersion) {
    return _sha256Hash(pin);
  }
}
