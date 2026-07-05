import { TypeOrmModuleOptions } from '@nestjs/typeorm';
import { Tenant } from '../common/entities/tenant.entity';
import { Device } from '../common/entities/device.entity';
import { PairingSession } from '../common/entities/pairing-session.entity';
import { BackupSnapshot } from '../common/entities/backup-snapshot.entity';
import { MpesaTransactionLog } from '../common/entities/mpesa-transaction-log.entity';
import { SyncRecord } from '../common/entities/sync-record.entity';
import { TenantMpesaConfig } from '../common/entities/tenant-mpesa-config.entity';

export const databaseConfig: TypeOrmModuleOptions = {
  type: 'postgres',
  url: process.env.DATABASE_URL || 'postgres://localhost:5432/pos_mashinani',
  entities: [
    Tenant,
    Device,
    PairingSession,
    BackupSnapshot,
    MpesaTransactionLog,
    SyncRecord,
    TenantMpesaConfig,
  ],
  synchronize: true,
  ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false,
  logging: process.env.NODE_ENV !== 'production' ? ['error', 'warn'] : ['error'],
};
