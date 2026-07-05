import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, UpdateDateColumn } from 'typeorm';

@Entity('tenant_mpesa_configs')
export class TenantMpesaConfig {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ unique: true })
  tenantId: string;

  @Column('text')
  encryptedConsumerKey: string;

  @Column('text')
  encryptedConsumerSecret: string;

  @Column('text')
  encryptedPasskey: string;

  @Column()
  shortcode: string;

  @Column({ default: true })
  isSandbox: boolean;

  @Column({ nullable: true })
  configuredBy: string;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
