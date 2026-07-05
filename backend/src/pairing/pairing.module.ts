import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { PairingSession } from '../common/entities/pairing-session.entity';
import { Device } from '../common/entities/device.entity';
import { Tenant } from '../common/entities/tenant.entity';
import { AuthModule } from '../auth/auth.module';
import { PairingController } from './pairing.controller';
import { PairingService } from './pairing.service';

@Module({
  imports: [
    TypeOrmModule.forFeature([PairingSession, Device, Tenant]),
    AuthModule,
  ],
  controllers: [PairingController],
  providers: [PairingService],
  exports: [PairingService],
})
export class PairingModule {}
