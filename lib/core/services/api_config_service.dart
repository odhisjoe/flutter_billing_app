import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiConfigService {
  final FlutterSecureStorage _storage;

  static const _serverUrlKey = 'api_server_url';
  static const _jwtTokenKey = 'api_jwt_token';
  static const _tenantIdKey = 'api_tenant_id';
  static const _deviceIdKey = 'api_device_id';

  ApiConfigService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  Future<void> saveServerUrl(String url) async {
    await _storage.write(key: _serverUrlKey, value: url);
  }

  Future<String> getServerUrl() async {
    final url = await _storage.read(key: _serverUrlKey);
    if (url != null && url.isNotEmpty) return url;
    return const String.fromEnvironment('API_BASE_URL');
  }

  Future<void> saveJwtToken(String token) async {
    await _storage.write(key: _jwtTokenKey, value: token);
  }

  Future<String?> getJwtToken() async {
    return _storage.read(key: _jwtTokenKey);
  }

  Future<void> saveTenantId(String tenantId) async {
    await _storage.write(key: _tenantIdKey, value: tenantId);
  }

  Future<String?> getTenantId() async {
    return _storage.read(key: _tenantIdKey);
  }

  Future<void> saveDeviceId(String deviceId) async {
    await _storage.write(key: _deviceIdKey, value: deviceId);
  }

  Future<String?> getDeviceId() async {
    return _storage.read(key: _deviceIdKey);
  }

  Future<bool> isConfigured() async {
    final url = await getServerUrl();
    final token = await getJwtToken();
    return url.isNotEmpty && token != null && token.isNotEmpty;
  }

  Future<void> clear() async {
    await _storage.delete(key: _serverUrlKey);
    await _storage.delete(key: _jwtTokenKey);
    await _storage.delete(key: _tenantIdKey);
    await _storage.delete(key: _deviceIdKey);
  }
}
