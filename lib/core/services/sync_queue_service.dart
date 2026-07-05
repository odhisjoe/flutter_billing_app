import 'dart:convert';
import 'package:dio/dio.dart';
import '../database/secondary_db.dart';
import '../service_locator.dart' as di;
import 'api_config_service.dart';

class SyncQueueService {
  final Dio _dio;

  SyncQueueService(this._dio);

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

  Future<void> enqueue({
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    await SecondaryDb.enqueueSync(
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      payload: jsonEncode(payload),
    );
  }

  Future<void> processPending() async {
    final pending = await SecondaryDb.getPendingSync(limit: 50);
    if (pending.isEmpty) return;

    final headers = await _headers();
    final serverUrl = await _serverUrl();
    if (headers == null || serverUrl.isEmpty) return;

    for (final item in pending) {
      await _processItem(item, serverUrl, headers);
    }
  }

  Future<void> _processItem(Map<String, dynamic> item, String serverUrl, Map<String, String> headers) async {
    final id = item['id'] as int;
    await SecondaryDb.updateSyncStatus(id, 'syncing');

    try {
      await _dio.post(
        '$serverUrl/api/sync/push',
        data: {
          'entries': [{
            'entityType': item['entity_type'],
            'entityId': item['entity_id'],
            'payload': jsonDecode(item['payload'] as String),
          }],
        },
        options: Options(headers: headers),
      );
      await SecondaryDb.updateSyncStatus(id, 'synced');
    } catch (e) {
      final retryCount = (item['retry_count'] as int? ?? 0) + 1;
      if (retryCount >= 5) {
        await SecondaryDb.updateSyncStatus(id, 'failed');
      } else {
        await SecondaryDb.incrementSyncRetry(id);
        await SecondaryDb.updateSyncStatus(id, 'pending');
      }
    }
  }

  static Future<int> pendingCount() => SecondaryDb.pendingSyncCount();
}
