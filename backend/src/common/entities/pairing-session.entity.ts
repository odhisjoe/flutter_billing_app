import {
  Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, ManyToOne, JoinColumn,
} from 'typeorm';
import { Tenant } from './tenant.entity';

@Entity('pairing_sessions')
export class PairingSession {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  tenantId: string;

  @ManyToOne(() => Tenant, (t) => t.pairingSessions)
  @JoinColumn({ name: 'tenantId' })
  tenant: Tenant;

  @Column({ unique: true })
  token: string;

  @Column({ length: 6 })
  pin: string;

  @Column({ default: 0 })
  failedAttempts: number;

  @Column({ default: 'pending' })
  status: string; // pending | linked | expired | revoked

  @Column({ nullable: true })
  deviceId: string;

  @Column({ nullable: true })
  deviceName: string;

  @Column()
  expiresAt: Date;

  @Column({ nullable: true })
  redeemedAt: Date;

  @CreateDateColumn()
  createdAt: Date;
}
