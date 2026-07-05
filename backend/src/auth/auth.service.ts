import { Injectable } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';

@Injectable()
export class AuthService {
  constructor(private readonly jwtService: JwtService) {}

  generateDeviceToken(deviceId: string, tenantId: string, deviceName: string): string {
    return this.jwtService.sign({
      sub: deviceId,
      tenantId,
      deviceName,
    });
  }

  generateTenantToken(tenantId: string): string {
    return this.jwtService.sign({
      sub: tenantId,
      tenantId,
      type: 'tenant-recovery',
    });
  }
}
