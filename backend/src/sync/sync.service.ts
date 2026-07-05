import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, LessThan } from 'typeorm';
import { SyncRecord } from '../common/entities/sync-record.entity';

@Injectable()
export class SyncService {
  constructor(
    @InjectRepository(SyncRecord)
    private readonly syncRepo: Repository<SyncRecord>,
  ) {}

  async push(
    tenantId: string,
    deviceId: string,
    entries: Array<{
      entityType: string;
      entityId: string;
      payload: Record<string, any>;
      version?: number;
    }>,
  ): Promise<{ applied: number }> {
    let applied = 0;

    for (const entry of entries) {
      const existing = await this.syncRepo.findOne({
        where: {
          tenantId,
          entityType: entry.entityType,
          entityId: entry.entityId,
        },
      });

      const incomingVersion = entry.version || 1;

      if (existing) {
        if (incomingVersion < existing.version) continue;
        existing.payload = entry.payload;
        existing.version = incomingVersion;
        existing.deviceId = deviceId;
        existing.updatedAt = new Date();
        await this.syncRepo.save(existing);
      } else {
        const record = this.syncRepo.create({
          tenantId,
          entityType: entry.entityType,
          entityId: entry.entityId,
          payload: entry.payload,
          version: incomingVersion,
          deviceId,
        });
        await this.syncRepo.save(record);
      }
      applied++;
    }

    return { applied };
  }

  async pull(
    tenantId: string,
    since?: string,
    entityType?: string,
  ): Promise<{
    records: SyncRecord[];
    timestamp: string;
  }> {
    const where: any = { tenantId };

    if (entityType) {
      where.entityType = entityType;
    }

    if (since) {
      where.updatedAt = LessThan(new Date(since));
    }

    const records = await this.syncRepo.find({
      where,
      order: { updatedAt: 'DESC' },
      take: 1000,
    });

    return {
      records,
      timestamp: new Date().toISOString(),
    };
  }

  async pullFull(tenantId: string): Promise<SyncRecord[]> {
    return this.syncRepo.find({
      where: { tenantId },
      order: { entityType: 'ASC', entityId: 'ASC' },
    });
  }
}
