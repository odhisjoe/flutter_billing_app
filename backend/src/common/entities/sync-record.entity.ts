import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, Index } from 'typeorm';

@Entity('sync_records')
@Index(['tenantId', 'entityType', 'entityId'], { unique: true })
export class SyncRecord {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  tenantId: string;

  @Column()
  entityType: string; // product, sale, customer, supplier, inventory, shop, user

  @Column()
  entityId: string;

  @Column({ type: 'jsonb' })
  payload: Record<string, any>;

  @Column({ default: 1 })
  version: number;

  @Column({ nullable: true })
  deviceId: string;

  @Column({ type: 'timestamptz', default: () => 'NOW()' })
  updatedAt: Date;

  @CreateDateColumn()
  createdAt: Date;
}
