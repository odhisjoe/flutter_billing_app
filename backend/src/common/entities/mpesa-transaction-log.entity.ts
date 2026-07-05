import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn } from 'typeorm';

@Entity('mpesa_transaction_logs')
export class MpesaTransactionLog {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  tenantId: string;

  @Column()
  checkoutRequestId: string;

  @Column({ nullable: true })
  mpesaReceiptNumber: string;

  @Column({ type: 'decimal', precision: 10, scale: 2, default: 0 })
  amount: number;

  @Column()
  phone: string;

  @Column()
  status: string; // initiated | success | failed

  @Column({ nullable: true })
  resultDesc: string;

  @Column({ default: false })
  redacted: boolean;

  @CreateDateColumn()
  createdAt: Date;
}
