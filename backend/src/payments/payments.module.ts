import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { MpesaTransactionLog } from '../common/entities/mpesa-transaction-log.entity';
import { TenantMpesaConfig } from '../common/entities/tenant-mpesa-config.entity';
import { AuthModule } from '../auth/auth.module';
import { MpesaController } from './mpesa.controller';
import { MpesaService } from './mpesa.service';

@Module({
  imports: [TypeOrmModule.forFeature([MpesaTransactionLog, TenantMpesaConfig]), AuthModule],
  controllers: [MpesaController],
  providers: [MpesaService],
})
export class PaymentsModule {}
