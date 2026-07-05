import 'package:dio/dio.dart';
import '../service_locator.dart' as di;
import 'api_config_service.dart';

class LinkingCodeInfo {
  final String code;
  final String? pin;
  final int expiresIn;

  LinkingCodeInfo({required this.code, this.pin, required this.expiresIn});
}

class ApiDeviceLinkingService {
  final Dio _dio;

  ApiDeviceLinkingService({Dio? dio})
      : _dio = dio ?? Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ));

  Future<Map<String, String>?> _headers() async {
    final config = di.sl<ApiConfigService>();
    final token = await config.getJwtToken();
    if (token == null) return null;
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  Future<String> _serverUrl() async {
    final config = di.sl<ApiConfigService>();
    return config.getServerUrl();
  }

  Future<LinkingCodeInfo?> createSession(String tenantId) async {
    final headers = await _headers();
    final serverUrl = await _serverUrl();
    if (headers == null || serverUrl.isEmpty) return null;

    try {
      final response = await _dio.post(
        '$serverUrl/api/pairing/create',
        data: {'tenantId': tenantId},
        options: Options(headers: headers),
      );
      return LinkingCodeInfo(
        code: response.data['token'] as String,
        pin: response.data['pin'] as String?,
        expiresIn: response.data['expiresIn'] as int? ?? 300,
      );
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> redeemSession(String code, String deviceName) async {
    final serverUrl = await _serverUrl();
    if (serverUrl.isEmpty) return null;

    try {
      final response = await _dio.post(
        '$serverUrl/api/pairing/redeem',
        data: {'code': code, 'deviceName': deviceName},
        options: Options(
          contentType: 'application/json',
          extra: {'noAuth': true},
        ),
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response?.statusCode == 400 || e.response?.statusCode == 403) {
        return {'error': e.response?.data?['message'] ?? e.message};
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> bootstrap(String shopName, String deviceName) async {
    final serverUrl = await _serverUrl();
    if (serverUrl.isEmpty) return null;

    try {
      final response = await _dio.post(
        '$serverUrl/api/pairing/bootstrap',
        data: {'shopName': shopName, 'deviceName': deviceName},
        options: Options(
          contentType: 'application/json',
          extra: {'noAuth': true},
        ),
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        return {'error': e.response?.data?['message'] ?? e.message};
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> createBackup() async {
    final headers = await _headers();
    final serverUrl = await _serverUrl();
    if (headers == null || serverUrl.isEmpty) return false;
    try {
      await _dio.post(
        '$serverUrl/api/backup/create',
        data: {'trigger': 'manual'},
        options: Options(headers: headers),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> setRecoveryPin() async {
    final headers = await _headers();
    final serverUrl = await _serverUrl();
    if (headers == null || serverUrl.isEmpty) return null;

    try {
      final response = await _dio.post(
        '$serverUrl/api/pairing/set-recovery-pin',
        options: Options(headers: headers),
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        return {'error': e.response?.data?['message'] ?? e.message};
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> redeemRecoveryPin({
    required String shopName,
    required String recoveryPin,
    required String deviceName,
  }) async {
    final serverUrl = await _serverUrl();
    if (serverUrl.isEmpty) return null;

    try {
      final response = await _dio.post(
        '$serverUrl/api/pairing/redeem-recovery',
        data: {
          'shopName': shopName,
          'recoveryPin': recoveryPin,
          'deviceName': deviceName,
        },
        options: Options(
          contentType: 'application/json',
          extra: {'noAuth': true},
        ),
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response?.statusCode == 400 || e.response?.statusCode == 403) {
        return {'error': e.response?.data?['message'] ?? e.message};
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> incrementFailedAttempts(String code) async {
    final serverUrl = await _serverUrl();
    if (serverUrl.isEmpty) return;
    try {
      await _dio.post(
        '$serverUrl/api/pairing/redeem/increment-failed',
        data: {'code': code},
      );
    } catch (_) {}
  }

  Future<List<dynamic>> getDevices() async {
    final headers = await _headers();
    final serverUrl = await _serverUrl();
    if (headers == null || serverUrl.isEmpty) return [];
    try {
      final response = await _dio.get(
        '$serverUrl/api/pairing/devices',
        options: Options(headers: headers),
      );
      return response.data as List<dynamic>;
    } catch (_) {
      return [];
    }
  }

  Future<bool> revokeDevice(String deviceId) async {
    final headers = await _headers();
    final serverUrl = await _serverUrl();
    if (headers == null || serverUrl.isEmpty) return false;
    try {
      await _dio.delete(
        '$serverUrl/api/pairing/devices/$deviceId',
        options: Options(headers: headers),
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
