import 'dart:convert';
import 'package:dio/dio.dart';
import '../database/secondary_db.dart';

class SyncQueueService {
  final Dio _dio;

  SyncQueueService(this._dio);

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

    for (final item in pending) {
      await _processItem(item);
    }
  }

  Future<void> _processItem(Map<String, dynamic> item) async {
    final id = item['id'] as int;
    await SecondaryDb.updateSyncStatus(id, 'syncing');

    try {
      await _dio.post(
        '/api/sync/${item['entity_type']}',
        data: {
          'operation': item['operation'],
          'payload': jsonDecode(item['payload'] as String),
        },
        options: Options(
          extra: {'noAuth': true},
        ),
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
