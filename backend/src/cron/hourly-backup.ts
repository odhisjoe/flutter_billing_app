import { NestFactory } from '@nestjs/core';
import { AppModule } from '../app.module';
import { BackupService } from '../backup/backup.service';

async function run() {
  const app = await NestFactory.createApplicationContext(AppModule);
  const backupService = app.get(BackupService);

  const tenants = await backupService['snapshotRepo'].query(
    'SELECT DISTINCT "tenantId" FROM sync_records',
  );

  for (const row of tenants) {
    try {
      await backupService.createSnapshot(row.tenantId, 'scheduled');
      console.log(`[HOURLY BACKUP] Snapshot created for tenant ${row.tenantId}`);
    } catch (e) {
      console.error(`[HOURLY BACKUP] Failed for tenant ${row.tenantId}:`, e.message);
    }
  }

  await app.close();
  process.exit(0);
}

run().catch((e) => {
  console.error('[HOURLY BACKUP] Fatal:', e);
  process.exit(1);
});
