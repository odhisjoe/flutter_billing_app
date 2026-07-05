import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/database/secondary_db.dart';
import '../../../core/services/api_config_service.dart';
import '../../../core/service_locator.dart' as di;

class MpesaConfig {
  final String consumerKey;
  final String consumerSecret;
  final String passkey;
  final String shortcode;
  final String serverUrl;
  final bool isSandbox;

  const MpesaConfig({
    this.consumerKey = '',
    this.consumerSecret = '',
    this.passkey = '',
    this.shortcode = '',
    this.serverUrl = '',
    this.isSandbox = true,
  });

  bool get isConfigured =>
      consumerKey.isNotEmpty &&
      consumerSecret.isNotEmpty &&
      passkey.isNotEmpty &&
      shortcode.isNotEmpty &&
      serverUrl.isNotEmpty;
}

class MpesaResult {
  final bool success;
  final String? checkoutRequestId;
  final String message;

  const MpesaResult({
    required this.success,
    this.checkoutRequestId,
    required this.message,
  });
}

class PaymentStatus {
  final bool paid;
  final String? mpesaRef;
  final bool found;

  const PaymentStatus({
    required this.paid,
    this.mpesaRef,
    this.found = false,
  });
}

class MpesaRepositoryImpl {
  final Dio _dio;
  final FlutterSecureStorage _secureStorage;

  static const _serverUrlKey = 'mpesa_server_url';
  static const _shortcodeKey = 'mpesa_shortcode';
  static const _isSandboxKey = 'mpesa_is_sandbox';
  static const _encryptedKey = 'mpesa_encrypted';

  MpesaRepositoryImpl({
    Dio? dio,
    FlutterSecureStorage? secureStorage,
  })  : _dio = dio ?? Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        )),
        _secureStorage = secureStorage ?? const FlutterSecureStorage();

  Future<enc.Key?> _deriveKey() async {
    try {
      final config = di.sl<ApiConfigService>();
      final token = await config.getJwtToken();
      if (token == null || token.isEmpty) return null;
      final hash = sha256.convert(utf8.encode(token)).toString();
      return enc.Key.fromUtf8(hash.substring(0, 32));
    } catch (_) {
      return null;
    }
  }

  Future<String?> _encryptLocal(String plaintext) async {
    final key = await _deriveKey();
    if (key == null) return null;
    try {
      final iv = enc.IV.fromSecureRandom(16);
      final encrypter = enc.Encrypter(enc.AES(key));
      final encrypted = encrypter.encrypt(plaintext, iv: iv);
      return '${iv.base64}:${encrypted.base64}';
    } catch (_) {
      return null;
    }
  }

  Future<String?> _decryptLocal(String ciphertext) async {
    final key = await _deriveKey();
    if (key == null) return null;
    try {
      final parts = ciphertext.split(':');
      if (parts.length != 2) return null;
      final iv = enc.IV.fromBase64(parts[0]);
      final encrypted = enc.Encrypted.fromBase64(parts[1]);
      final encrypter = enc.Encrypter(enc.AES(key));
      return encrypter.decrypt(encrypted, iv: iv);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, String>?> _authHeaders() async {
    if (kIsWeb) return null;
    final config = di.sl<ApiConfigService>();
    final token = await config.getJwtToken();
    if (token == null) return null;
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  Future<MpesaConfig> loadConfig() async {
    final headers = await _authHeaders();
    final configService = di.sl<ApiConfigService>();
    final serverUrl = await configService.getServerUrl();

    if (headers != null && serverUrl.isNotEmpty) {
      try {
        await _dio.get(
          '$serverUrl/api/payments/mpesa/config',
          options: Options(headers: headers),
        );
      } catch (_) {}
    }

    String consumerKey = '';
    String consumerSecret = '';
    String passkey = '';
    String shortcode = '';
    String mpesaServerUrl = '';
    bool isSandbox = true;

    if (!kIsWeb) {
      mpesaServerUrl = (await _secureStorage.read(key: _serverUrlKey)) ?? '';
      shortcode = (await _secureStorage.read(key: _shortcodeKey)) ?? '';
      isSandbox = (await _secureStorage.read(key: _isSandboxKey) ?? 'true') == 'true';

      final encryptedStore = await _secureStorage.read(key: _encryptedKey);
      if (encryptedStore != null) {
        final json = await _decryptLocal(encryptedStore);
        if (json != null) {
          try {
            final data = jsonDecode(json) as Map<String, dynamic>;
            consumerKey = data['consumerKey'] as String? ?? '';
            consumerSecret = data['consumerSecret'] as String? ?? '';
            passkey = data['passkey'] as String? ?? '';
          } catch (_) {}
        }
      }
    } else {
      final dbConfig = await SecondaryDb.getMpesaConfig();
      if (dbConfig != null) {
        mpesaServerUrl = (dbConfig['server_url'] as String?) ?? '';
        shortcode = (dbConfig['shortcode'] as String?) ?? '';
        isSandbox = (dbConfig['is_sandbox'] as int? ?? 1) == 1;

        final encryptedStore = dbConfig['encrypted'] as String?;
        if (encryptedStore != null && encryptedStore.isNotEmpty) {
          final json = await _decryptLocal(encryptedStore);
          if (json != null) {
            try {
              final data = jsonDecode(json) as Map<String, dynamic>;
              consumerKey = data['consumerKey'] as String? ?? '';
              consumerSecret = data['consumerSecret'] as String? ?? '';
              passkey = data['passkey'] as String? ?? '';
            } catch (_) {}
          }
        }
      }
    }

    return MpesaConfig(
      consumerKey: consumerKey,
      consumerSecret: consumerSecret,
      passkey: passkey,
      shortcode: shortcode,
      serverUrl: mpesaServerUrl,
      isSandbox: isSandbox,
    );
  }

  Future<void> saveConfig(MpesaConfig config) async {
    final headers = await _authHeaders();
    final configService = di.sl<ApiConfigService>();
    final serverUrl = await configService.getServerUrl();

    if (headers != null && serverUrl.isNotEmpty) {
      try {
        final response = await _dio.post(
          '$serverUrl/api/payments/mpesa/config',
          data: {
            'consumerKey': config.consumerKey,
            'consumerSecret': config.consumerSecret,
            'passkey': config.passkey,
            'shortcode': config.shortcode,
            'isSandbox': config.isSandbox,
          },
          options: Options(headers: headers),
        );
        if (response.data['configured'] != true) {
          throw Exception(response.data['message'] ?? 'Failed to save config');
        }
      } on DioException catch (e) {
        final msg = e.response?.data?['message'] ?? e.message ?? 'Connection failed';
        throw Exception(msg);
      }
    } else {
      throw Exception('Server not configured. Link your device first.');
    }

    final secretPayload = jsonEncode({
      'consumerKey': config.consumerKey,
      'consumerSecret': config.consumerSecret,
      'passkey': config.passkey,
    });
    final encrypted = await _encryptLocal(secretPayload);

    if (!kIsWeb) {
      await _secureStorage.write(key: _serverUrlKey, value: config.serverUrl);
      await _secureStorage.write(key: _shortcodeKey, value: config.shortcode);
      await _secureStorage.write(key: _isSandboxKey, value: config.isSandbox.toString());
      if (encrypted != null) {
        await _secureStorage.write(key: _encryptedKey, value: encrypted);
      }
    }

    await SecondaryDb.saveMpesaConfig(
      consumerKey: '',
      consumerSecret: '',
      passkey: '',
      shortcode: config.shortcode,
      serverUrl: config.serverUrl,
      isSandbox: config.isSandbox,
      encrypted: encrypted ?? '',
    );
  }

  Future<MpesaResult> stkPush({
    required String phone,
    required double amount,
    required String reference,
  }) async {
    try {
      final headers = await _authHeaders();
      final configService = di.sl<ApiConfigService>();
      final serverUrl = await configService.getServerUrl();

      if (headers == null || serverUrl.isEmpty) {
        return const MpesaResult(
          success: false,
          message: 'Server not configured. Link your device first.',
        );
      }

      final response = await _dio.post(
        '$serverUrl/api/payments/mpesa/stk-push',
        data: {
          'phone': phone,
          'amount': amount.toInt(),
          'reference': reference,
          'description': 'POS Payment',
        },
        options: Options(headers: headers),
      );

      final checkoutId = response.data['CheckoutRequestID'] as String?;
      if (checkoutId == null) {
        return MpesaResult(
          success: false,
          message: response.data['errorMessage'] ?? response.data['message'] ?? 'Failed to initiate payment',
        );
      }

      await SecondaryDb.insertMpesaRequest(
        checkoutRequestId: checkoutId,
        saleId: reference,
        amount: amount,
        phone: phone,
      );

      return MpesaResult(
        success: true,
        checkoutRequestId: checkoutId,
        message: 'STK Push sent. Check phone to enter PIN.',
      );
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? e.message ?? 'Connection failed';
      return MpesaResult(success: false, message: msg);
    } catch (e) {
      return MpesaResult(success: false, message: e.toString());
    }
  }

  Future<PaymentStatus> checkStatus(String checkoutRequestId) async {
    try {
      final headers = await _authHeaders();
      final configService = di.sl<ApiConfigService>();
      final serverUrl = await configService.getServerUrl();

      if (headers == null || serverUrl.isEmpty) {
        return const PaymentStatus(paid: false);
      }

      final response = await _dio.post(
        '$serverUrl/api/payments/mpesa/status',
        data: {'checkoutRequestId': checkoutRequestId},
        options: Options(headers: headers),
      );

      final paid = response.data['paid'] as bool? ?? false;
      final mpesaRef = response.data['mpesaRef'] as String?;

      if (paid && mpesaRef != null) {
        await SecondaryDb.confirmMpesaPayment(
          checkoutRequestId: checkoutRequestId,
          mpesaRef: mpesaRef,
        );
      }

      return PaymentStatus(
        paid: paid,
        mpesaRef: mpesaRef,
        found: response.data['found'] as bool? ?? false,
      );
    } catch (_) {
      return const PaymentStatus(paid: false);
    }
  }

  Future<MpesaResult> testConnection() async {
    try {
      final headers = await _authHeaders();
      final configService = di.sl<ApiConfigService>();
      final serverUrl = await configService.getServerUrl();

      if (headers == null || serverUrl.isEmpty) {
        return const MpesaResult(
          success: false,
          message: 'Server not configured. Link your device first.',
        );
      }

      final response = await _dio.post(
        '$serverUrl/api/payments/mpesa/test-connection',
        options: Options(headers: headers),
      );

      return MpesaResult(
        success: response.data['success'] == true,
        message: response.data['message'] ?? 'Test completed',
      );
    } on DioException catch (e) {
      return MpesaResult(
        success: false,
        message: 'Cannot reach server: ${e.message}',
      );
    }
  }
}
