import {
  Controller, Post, Get, Body, UseGuards, HttpCode, HttpStatus,
} from '@nestjs/common';
import { BackupService } from './backup.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentDevice } from '../auth/current-device.decorator';

class RestoreDto {
  records: Array<{
    entityType: string;
    entityId: string;
    payload: Record<string, any>;
    version?: number;
  }>;
}

@Controller('backup')
@UseGuards(JwtAuthGuard)
export class BackupController {
  constructor(private readonly backupService: BackupService) {}

  @Post('create')
  @HttpCode(HttpStatus.OK)
  async createSnapshot(
    @Body() dto: { trigger?: string },
    @CurrentDevice() device: any,
  ) {
    return this.backupService.createSnapshot(
      device.tenantId,
      dto.trigger === 'scheduled' ? 'scheduled' : 'manual',
    );
  }

  @Get('list')
  async listSnapshots(@CurrentDevice() device: any) {
    return this.backupService.listSnapshots(device.tenantId);
  }

  @Post('restore')
  @HttpCode(HttpStatus.OK)
  async restore(@Body() dto: RestoreDto, @CurrentDevice() device: any) {
    return this.backupService.restoreData(device.tenantId, dto.records);
  }
}
