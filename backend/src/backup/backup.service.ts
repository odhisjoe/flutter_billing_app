import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { S3Client, PutObjectCommand, GetObjectCommand } from '@aws-sdk/client-s3';
import { BackupSnapshot } from '../common/entities/backup-snapshot.entity';
import { SyncRecord } from '../common/entities/sync-record.entity';

@Injectable()
export class BackupService {
  private s3: S3Client | null = null;
  private bucketName: string = '';

  constructor(
    @InjectRepository(BackupSnapshot)
    private readonly snapshotRepo: Repository<BackupSnapshot>,
    @InjectRepository(SyncRecord)
    private readonly syncRepo: Repository<SyncRecord>,
  ) {
    const endpoint = process.env.BACKUP_STORAGE_ENDPOINT;
    const region = process.env.BACKUP_STORAGE_REGION || 'auto';
    const bucket = process.env.BACKUP_STORAGE_BUCKET;
    const accessKeyId = process.env.BACKUP_STORAGE_ACCESS_KEY;
    const secretAccessKey = process.env.BACKUP_STORAGE_SECRET_KEY;

    if (endpoint && bucket && accessKeyId && secretAccessKey) {
      this.s3 = new S3Client({
        endpoint,
        region,
        credentials: { accessKeyId, secretAccessKey },
        forcePathStyle: true,
      });
      this.bucketName = bucket;
    }
  }

  async createSnapshot(tenantId: string, trigger: 'scheduled' | 'manual' = 'manual'): Promise<{ id: string; path: string }> {
    const records = await this.syncRepo.find({ where: { tenantId } });

    const data = {
      tenantId,
      exportedAt: new Date().toISOString(),
      version: 1,
      records: records.map((r) => ({
        entityType: r.entityType,
        entityId: r.entityId,
        payload: r.payload,
        version: r.version,
        updatedAt: r.updatedAt,
      })),
    };

    const payload = JSON.stringify(data, null, 2);
    const key = `backups/${tenantId}/${Date.now()}.json`;

    if (this.s3) {
      await this.s3.send(new PutObjectCommand({
        Bucket: this.bucketName,
        Key: key,
        Body: payload,
        ContentType: 'application/json',
      }));
    } else {
      console.warn('[BACKUP] No object storage configured. Backup payload not persisted to external storage.');
      console.warn('[BACKUP] Set BACKUP_STORAGE_ENDPOINT, BACKUP_STORAGE_BUCKET, BACKUP_STORAGE_ACCESS_KEY, BACKUP_STORAGE_SECRET_KEY to enable.');
    }

    const snapshot = this.snapshotRepo.create({
      tenantId,
      storagePath: key,
      trigger,
      sizeBytes: Buffer.byteLength(payload, 'utf-8'),
    });
    await this.snapshotRepo.save(snapshot);

    return { id: snapshot.id, path: key };
  }

  async listSnapshots(tenantId: string): Promise<BackupSnapshot[]> {
    return this.snapshotRepo.find({
      where: { tenantId },
      order: { createdAt: 'DESC' },
      take: 50,
    });
  }

  async restoreData(tenantId: string, records: Array<{
    entityType: string;
    entityId: string;
    payload: Record<string, any>;
    version?: number;
  }>): Promise<{ restored: number }> {
    let restored = 0;
    for (const record of records) {
      const existing = await this.syncRepo.findOne({
        where: { tenantId, entityType: record.entityType, entityId: record.entityId },
      });

      if (existing) {
        existing.payload = record.payload;
        existing.version = (record.version || 1) + 1;
        await this.syncRepo.save(existing);
      } else {
        await this.syncRepo.save({
          tenantId,
          entityType: record.entityType,
          entityId: record.entityId,
          payload: record.payload,
          version: record.version || 1,
        });
      }
      restored++;
    }
    return { restored };
  }
}
