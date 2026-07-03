import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/database/secondary_db.dart';

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

  MpesaRepositoryImpl({
    Dio? dio,
    FlutterSecureStorage? secureStorage,
  })  : _dio = dio ?? Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        )),
        _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const _configKey = 'mpesa_server_url';

  Future<MpesaConfig> loadConfig() async {
    final dbConfig = await SecondaryDb.getMpesaConfig();
    if (dbConfig != null) {
      return MpesaConfig(
        consumerKey: dbConfig['consumer_key'] as String? ?? '',
        consumerSecret: dbConfig['consumer_secret'] as String? ?? '',
        passkey: dbConfig['passkey'] as String? ?? '',
        shortcode: dbConfig['shortcode'] as String? ?? '',
        serverUrl: dbConfig['server_url'] as String? ?? '',
        isSandbox: (dbConfig['is_sandbox'] as int? ?? 1) == 1,
      );
    }
    return const MpesaConfig();
  }

  Future<void> saveConfig(MpesaConfig config) async {
    await SecondaryDb.saveMpesaConfig(
      consumerKey: config.consumerKey,
      consumerSecret: config.consumerSecret,
      passkey: config.passkey,
      shortcode: config.shortcode,
      serverUrl: config.serverUrl,
      isSandbox: config.isSandbox,
    );
    if (!kIsWeb) {
      await _secureStorage.write(key: _configKey, value: config.serverUrl);
    }
  }

  Future<MpesaResult> stkPush({
    required String phone,
    required double amount,
    required String reference,
  }) async {
    try {
      final config = await loadConfig();
      if (!config.isConfigured) {
        return const MpesaResult(
          success: false,
          message: 'M-Pesa not configured. Go to Settings → Payments to set up.',
        );
      }

      final response = await _dio.post(
        '${config.serverUrl}/api/mpesa/stk-push',
        data: {
          'phone': phone,
          'amount': amount.toInt(),
          'reference': reference,
          'description': 'POS Payment',
        },
      );

      final checkoutId = response.data['CheckoutRequestID'] as String?;
      if (checkoutId == null) {
        return MpesaResult(
          success: false,
          message: response.data['errorMessage'] ?? 'Failed to initiate payment',
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
      final config = await loadConfig();
      if (!config.isConfigured) {
        return const PaymentStatus(paid: false);
      }

      final response = await _dio.get(
        '${config.serverUrl}/api/mpesa/status/$checkoutRequestId',
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
      final config = await loadConfig();
      if (!config.isConfigured) {
        return const MpesaResult(
          success: false,
          message: 'Configure M-Pesa settings first',
        );
      }

      final response = await _dio.get('${config.serverUrl}/api/health');
      return MpesaResult(
        success: true,
        message: response.data['mpesaConfigured'] == true
            ? 'Server connected and M-Pesa configured'
            : 'Server connected but M-Pesa credentials not set on server',
      );
    } on DioException catch (e) {
      return MpesaResult(
        success: false,
        message: 'Cannot reach server: ${e.message}',
      );
    }
  }
}
