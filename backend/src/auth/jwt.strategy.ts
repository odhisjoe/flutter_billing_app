import { Injectable, UnauthorizedException } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Device } from '../common/entities/device.entity';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(
    @InjectRepository(Device)
    private readonly deviceRepo: Repository<Device>,
  ) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: process.env.JWT_SECRET || 'pos-dev-secret-change-in-production',
    });
  }

  async validate(payload: { sub: string; tenantId: string; type?: string }) {
    if (payload.type === 'tenant-recovery') {
      return { tenantId: payload.tenantId, isRecovery: true };
    }

    const device = await this.deviceRepo.findOne({
      where: { id: payload.sub, isActive: true },
    });

    if (!device) {
      throw new UnauthorizedException('Device not found or revoked');
    }

    return {
      deviceId: device.id,
      tenantId: device.tenantId,
      deviceName: device.deviceName,
    };
  }
}
