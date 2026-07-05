import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn } from 'typeorm';

@Entity('backup_snapshots')
export class BackupSnapshot {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  tenantId: string;

  @Column()
  storagePath: string;

  @Column({ default: 'scheduled' })
  trigger: string; // scheduled | manual

  @Column({ nullable: true })
  sizeBytes: number;

  @CreateDateColumn()
  createdAt: Date;
}
