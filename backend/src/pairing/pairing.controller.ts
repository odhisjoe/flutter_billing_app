import {
  Controller, Post, Get, Delete, Body, Param, UseGuards, HttpCode, HttpStatus,
} from '@nestjs/common';
import { PairingService } from './pairing.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentDevice } from '../auth/current-device.decorator';
import { BootstrapDto } from './bootstrap.dto';

class CreatePairingDto {
  tenantId: string;
}

class RedeemPairingDto {
  code: string;
  deviceName?: string;
}

class RedeemRecoveryDto {
  shopName: string;
  recoveryPin: string;
  deviceName?: string;
}

class SetRecoveryPinDto {
  currentPin?: string;
}

@Controller('pairing')
export class PairingController {
  constructor(private readonly pairingService: PairingService) {}

  @Post('bootstrap')
  @HttpCode(HttpStatus.CREATED)
  async bootstrap(@Body() dto: BootstrapDto) {
    return this.pairingService.bootstrap(dto.shopName, dto.deviceName || '');
  }

  @UseGuards(JwtAuthGuard)
  @Post('create')
  async create(@Body() dto: CreatePairingDto, @CurrentDevice() device: any) {
    const tenantId = device.tenantId || dto.tenantId;
    return this.pairingService.createSession(tenantId);
  }

  @Post('redeem')
  @HttpCode(HttpStatus.OK)
  async redeem(@Body() dto: RedeemPairingDto) {
    return this.pairingService.redeemSession(dto.code, dto.deviceName || '');
  }

  @Post('redeem/increment-failed')
  @HttpCode(HttpStatus.OK)
  async incrementFailed(@Body() dto: { code: string }) {
    await this.pairingService.incrementFailedAttempts(dto.code);
    return { ok: true };
  }

  @Post('redeem-recovery')
  @HttpCode(HttpStatus.OK)
  async redeemRecovery(@Body() dto: RedeemRecoveryDto) {
    return this.pairingService.redeemRecoveryPin(
      dto.shopName,
      dto.recoveryPin,
      dto.deviceName || '',
    );
  }

  @UseGuards(JwtAuthGuard)
  @Post('set-recovery-pin')
  @HttpCode(HttpStatus.OK)
  async setRecoveryPin(@Body() dto: SetRecoveryPinDto, @CurrentDevice() device: any) {
    return this.pairingService.setRecoveryPin(device.tenantId, dto.currentPin);
  }

  @UseGuards(JwtAuthGuard)
  @Get('devices')
  async listDevices(@CurrentDevice() device: any) {
    return this.pairingService.getDevices(device.tenantId);
  }

  @UseGuards(JwtAuthGuard)
  @Delete('devices/:id')
  @HttpCode(HttpStatus.NO_CONTENT)
  async revokeDevice(@Param('id') id: string, @CurrentDevice() device: any) {
    await this.pairingService.revokeDevice(id, device.tenantId);
  }
}
