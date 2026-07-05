import {
  Controller, Post, Get, Body, Query, UseGuards, HttpCode, HttpStatus,
} from '@nestjs/common';
import { SyncService } from './sync.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentDevice } from '../auth/current-device.decorator';

class PushEntryDto {
  entityType: string;
  entityId: string;
  payload: Record<string, any>;
  version?: number;
}

class PushDto {
  entries: PushEntryDto[];
}

@Controller('sync')
@UseGuards(JwtAuthGuard)
export class SyncController {
  constructor(private readonly syncService: SyncService) {}

  @Post('push')
  @HttpCode(HttpStatus.OK)
  async push(@Body() dto: PushDto, @CurrentDevice() device: any) {
    return this.syncService.push(device.tenantId, device.deviceId, dto.entries);
  }

  @Get('pull')
  async pull(
    @Query('since') since: string,
    @Query('entityType') entityType: string,
    @CurrentDevice() device: any,
  ) {
    return this.syncService.pull(device.tenantId, since, entityType);
  }

  @Get('pull/full')
  async pullFull(@CurrentDevice() device: any) {
    return this.syncService.pullFull(device.tenantId);
  }
}
