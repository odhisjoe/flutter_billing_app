import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import '../database/secondary_db.dart';

const String syncTaskName = 'pos_background_sync';

@pragma('vm:entry-point')
void syncCallbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName == syncTaskName) {
      await _performBackgroundSync();
    }
    return true;
  });
}

Future<void> _performBackgroundSync() async {
  try {
    final pending = await SecondaryDb.getPendingSync(limit: 50);
    for (final item in pending) {
      final retryCount = (item['retry_count'] as int? ?? 0) + 1;
      if (retryCount >= 5) {
        await SecondaryDb.updateSyncStatus(item['id'] as int, 'failed');
      } else {
        await SecondaryDb.incrementSyncRetry(item['id'] as int);
      }
    }
  } catch (_) {}
}

Future<void> initializeWorkmanager() async {
  if (kIsWeb) return;
  await Workmanager().initialize(syncCallbackDispatcher, isInDebugMode: false);
  await Workmanager().registerPeriodicTask(
    syncTaskName,
    syncTaskName,
    frequency: const Duration(minutes: 15),
    constraints: Constraints(
      networkType: NetworkType.connected,
      requiresBatteryNotLow: true,
    ),
    existingWorkPolicy: ExistingWorkPolicy.replace,
  );
}
