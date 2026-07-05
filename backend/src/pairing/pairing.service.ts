import { Injectable, BadRequestException, ForbiddenException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import * as crypto from 'crypto';
import { PairingSession } from '../common/entities/pairing-session.entity';
import { Device } from '../common/entities/device.entity';
import { Tenant } from '../common/entities/tenant.entity';
import { AuthService } from '../auth/auth.service';

const CHARS = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const RECOVERY_CHARS = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
const PBKDF2_ITERATIONS = 100000;
const PBKDF2_KEYLEN = 32;

@Injectable()
export class PairingService {
  constructor(
    @InjectRepository(PairingSession)
    private readonly sessionRepo: Repository<PairingSession>,
    @InjectRepository(Device)
    private readonly deviceRepo: Repository<Device>,
    @InjectRepository(Tenant)
    private readonly tenantRepo: Repository<Tenant>,
    private readonly authService: AuthService,
  ) {}

  async createSession(tenantId: string): Promise<{ token: string; pin: string; expiresIn: number }> {
    const token = this.generateToken(32);
    const pin = this.generatePin();

    const session = this.sessionRepo.create({
      tenantId,
      token,
      pin,
      status: 'pending',
      expiresAt: new Date(Date.now() + 5 * 60 * 1000),
    });
    await this.sessionRepo.save(session);

    return { token, pin, expiresIn: 300 };
  }

  async redeemSession(
    code: string,
    deviceName: string,
  ): Promise<{ token: string; tenantId: string; deviceId: string }> {
    const session = await this.sessionRepo.findOne({
      where: [
        { token: code, status: 'pending' },
        { pin: code.toUpperCase(), status: 'pending' },
      ],
      relations: ['tenant'],
    });

    if (!session) {
      throw new BadRequestException('Invalid pairing code');
    }

    if (new Date() > session.expiresAt) {
      session.status = 'expired';
      await this.sessionRepo.save(session);
      throw new BadRequestException('Pairing code has expired');
    }

    if (session.failedAttempts >= 5) {
      session.status = 'revoked';
      await this.sessionRepo.save(session);
      throw new ForbiddenException('Too many failed attempts. Generate a new code.');
    }

    const device = this.deviceRepo.create({
      tenantId: session.tenantId,
      deviceName: deviceName || `Device-${crypto.randomBytes(3).toString('hex')}`,
    });
    await this.deviceRepo.save(device);

    session.status = 'linked';
    session.deviceId = device.id;
    session.deviceName = device.deviceName;
    session.redeemedAt = new Date();
    await this.sessionRepo.save(session);

    const jwt = this.authService.generateDeviceToken(
      device.id,
      session.tenantId,
      device.deviceName,
    );

    return { token: jwt, tenantId: session.tenantId, deviceId: device.id };
  }

  async incrementFailedAttempts(code: string): Promise<void> {
    const session = await this.sessionRepo.findOne({
      where: [
        { token: code, status: 'pending' },
        { pin: code.toUpperCase(), status: 'pending' },
      ],
    });
    if (session) {
      session.failedAttempts += 1;
      await this.sessionRepo.save(session);
    }
  }

  async getDevices(tenantId: string): Promise<Device[]> {
    return this.deviceRepo.find({
      where: { tenantId, isActive: true },
      order: { pairedAt: 'DESC' },
    });
  }

  async revokeDevice(deviceId: string, tenantId: string): Promise<void> {
    const device = await this.deviceRepo.findOne({
      where: { id: deviceId, tenantId },
    });
    if (!device) throw new BadRequestException('Device not found');
    device.isActive = false;
    device.revokedAt = new Date();
    await this.deviceRepo.save(device);
  }

  async bootstrap(shopName: string, deviceName: string): Promise<{ token: string; tenantId: string; deviceId: string; recoveryPin: string }> {
    const recoveryPin = this.generateRecoveryPin();
    const recoveryPinHash = await this.hashPin(recoveryPin);

    const tenant = this.tenantRepo.create({
      name: shopName,
      recoveryPinHash,
    });
    await this.tenantRepo.save(tenant);

    const device = this.deviceRepo.create({
      tenantId: tenant.id,
      deviceName: deviceName || `Owner-${crypto.randomBytes(3).toString('hex')}`,
    });
    await this.deviceRepo.save(device);

    const jwt = this.authService.generateDeviceToken(device.id, tenant.id, device.deviceName);

    return { token: jwt, tenantId: tenant.id, deviceId: device.id, recoveryPin };
  }

  async setRecoveryPin(tenantId: string, currentPinHash?: string): Promise<{ recoveryPin: string }> {
    const tenant = await this.tenantRepo.findOne({ where: { id: tenantId } });
    if (!tenant) throw new BadRequestException('Tenant not found');

    if (tenant.recoveryPinHash && !currentPinHash) {
      throw new BadRequestException('A recovery PIN is already set. Provide current PIN to reset.');
    }

    const recoveryPin = this.generateRecoveryPin();
    tenant.recoveryPinHash = await this.hashPin(recoveryPin);
    await this.tenantRepo.save(tenant);

    return { recoveryPin };
  }

  async redeemRecoveryPin(
    shopName: string,
    recoveryPin: string,
    deviceName: string,
  ): Promise<{ token: string; tenantId: string; deviceId: string }> {
    const tenant = await this.tenantRepo.findOne({ where: { name: shopName } });
    if (!tenant || !tenant.recoveryPinHash) {
      throw new BadRequestException('Invalid shop name or recovery PIN not configured');
    }

    const isValid = await this.verifyPin(recoveryPin.toUpperCase(), tenant.recoveryPinHash);
    if (!isValid) {
      throw new ForbiddenException('Invalid recovery PIN');
    }

    const device = this.deviceRepo.create({
      tenantId: tenant.id,
      deviceName: deviceName || `Recovered-${crypto.randomBytes(3).toString('hex')}`,
    });
    await this.deviceRepo.save(device);

    const jwt = this.authService.generateDeviceToken(device.id, tenant.id, device.deviceName);

    return { token: jwt, tenantId: tenant.id, deviceId: device.id };
  }

  private async hashPin(pin: string): Promise<string> {
    const salt = crypto.randomBytes(16).toString('hex');
    const hash = await new Promise<string>((resolve, reject) => {
      crypto.pbkdf2(pin, salt, PBKDF2_ITERATIONS, PBKDF2_KEYLEN, 'sha256', (err, key) => {
        if (err) reject(err);
        else resolve(`${salt}:${key.toString('hex')}`);
      });
    });
    return hash;
  }

  private async verifyPin(pin: string, stored: string): Promise<boolean> {
    const [salt, key] = stored.split(':');
    const hash = await new Promise<string>((resolve, reject) => {
      crypto.pbkdf2(pin, salt, PBKDF2_ITERATIONS, PBKDF2_KEYLEN, 'sha256', (err, derivedKey) => {
        if (err) reject(err);
        else resolve(derivedKey.toString('hex'));
      });
    });
    return hash === key;
  }

  private generateToken(length: number): string {
    return crypto.randomBytes(length).toString('hex');
  }

  private generatePin(): string {
    let pin = '';
    for (let i = 0; i < 6; i++) {
      pin += CHARS[crypto.randomInt(CHARS.length)];
    }
    return pin;
  }

  private generateRecoveryPin(): string {
    const segments: string[] = [];
    for (let s = 0; s < 3; s++) {
      let segment = '';
      for (let i = 0; i < 4; i++) {
        segment += RECOVERY_CHARS[crypto.randomInt(RECOVERY_CHARS.length)];
      }
      segments.push(segment);
    }
    return segments.join('-');
  }
}
