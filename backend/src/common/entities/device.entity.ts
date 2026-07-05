import {
  Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, UpdateDateColumn, ManyToOne, JoinColumn,
} from 'typeorm';
import { Tenant } from './tenant.entity';

@Entity('devices')
export class Device {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  tenantId: string;

  @ManyToOne(() => Tenant, (t) => t.devices)
  @JoinColumn({ name: 'tenantId' })
  tenant: Tenant;

  @Column()
  deviceName: string;

  @Column({ nullable: true })
  deviceType: string;

  @Column({ default: true })
  isActive: boolean;

  @Column({ nullable: true })
  lastSyncedAt: Date;

  @Column({ nullable: true })
  revokedAt: Date;

  @CreateDateColumn()
  pairedAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
