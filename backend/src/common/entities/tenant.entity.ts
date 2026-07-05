import {
  Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, UpdateDateColumn, OneToMany,
} from 'typeorm';
import { Device } from './device.entity';
import { PairingSession } from './pairing-session.entity';

@Entity('tenants')
export class Tenant {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ unique: true })
  name: string;

  @Column({ nullable: true })
  recoveryPin: string;

  @Column({ nullable: true })
  recoveryPinHash: string;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;

  @OneToMany(() => Device, (d) => d.tenant)
  devices: Device[];

  @OneToMany(() => PairingSession, (p) => p.tenant)
  pairingSessions: PairingSession[];
}
