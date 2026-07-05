import {
  Controller, Post, Get, Delete, Body, UseGuards, HttpCode, HttpStatus,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { MpesaService } from './mpesa.service';
import { EncryptionService } from '../common/encryption.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentDevice } from '../auth/current-device.decorator';
import { MpesaTransactionLog } from '../common/entities/mpesa-transaction-log.entity';
import { TenantMpesaConfig } from '../common/entities/tenant-mpesa-config.entity';

class SaveConfigDto {
  consumerKey: string;
  consumerSecret: string;
  passkey: string;
  shortcode: string;
  isSandbox: boolean;
}

class StkPushDto {
  phone: string;
  amount: number;
  reference: string;
  description?: string;
}

@Controller('payments/mpesa')
@UseGuards(JwtAuthGuard)
export class MpesaController {
  constructor(
    private readonly mpesaService: MpesaService,
    private readonly encryption: EncryptionService,
    @InjectRepository(MpesaTransactionLog)
    private readonly logRepo: Repository<MpesaTransactionLog>,
    @InjectRepository(TenantMpesaConfig)
    private readonly configRepo: Repository<TenantMpesaConfig>,
  ) {}

  // ── Config endpoints ─────────────────────────────────────────

  @Post('config')
  @HttpCode(HttpStatus.OK)
  async saveConfig(@Body() dto: SaveConfigDto, @CurrentDevice() device: any) {
    const baseUrl = dto.isSandbox
      ? 'https://sandbox.safaricom.co.ke'
      : 'https://api.safaricom.co.ke';

    try {
      const { default: axios } = await import('axios');
      const creds = Buffer.from(`${dto.consumerKey}:${dto.consumerSecret}`).toString('base64');
      await axios.get(
        `${baseUrl}/oauth/v1/generate?grant_type=client_credentials`,
        { headers: { Authorization: `Basic ${creds}` } },
      );
    } catch (e: any) {
      return {
        configured: false,
        message: 'Credentials validation failed: ' + (e.response?.data?.errorMessage || e.message),
      };
    }

    const encrypted = {
      encryptedConsumerKey: this.encryption.encrypt(dto.consumerKey),
      encryptedConsumerSecret: this.encryption.encrypt(dto.consumerSecret),
      encryptedPasskey: this.encryption.encrypt(dto.passkey),
      shortcode: dto.shortcode,
      isSandbox: dto.isSandbox,
      configuredBy: device.deviceId || device.tenantId,
    };

    await this.configRepo.upsert(
      { tenantId: device.tenantId, ...encrypted },
      ['tenantId'],
    );

    return { configured: true, message: 'Credentials validated and saved' };
  }

  @Get('config')
  @HttpCode(HttpStatus.OK)
  async getConfig(@CurrentDevice() device: any) {
    const config = await this.configRepo.findOne({
      where: { tenantId: device.tenantId },
    });
    return { configured: !!config };
  }

  @Delete('config')
  @HttpCode(HttpStatus.OK)
  async deleteConfig(@CurrentDevice() device: any) {
    await this.configRepo.delete({ tenantId: device.tenantId });
    return { configured: false };
  }

  // ── STK Push ─────────────────────────────────────────────────

  @Post('stk-push')
  @HttpCode(HttpStatus.OK)
  async stkPush(@Body() dto: StkPushDto, @CurrentDevice() device: any) {
    const config = await this.configRepo.findOne({
      where: { tenantId: device.tenantId },
    });
    if (!config) {
      return { success: false, message: 'M-Pesa not configured. Save credentials in settings first.' };
    }

    const callbackUrl = `${process.env.SERVER_URL || ''}/api/payments/mpesa/callback`;

    const result = await this.mpesaService.stkPush({
      consumerKey: this.encryption.decrypt(config.encryptedConsumerKey),
      consumerSecret: this.encryption.decrypt(config.encryptedConsumerSecret),
      passkey: this.encryption.decrypt(config.encryptedPasskey),
      shortcode: config.shortcode,
      phone: dto.phone,
      amount: dto.amount,
      reference: dto.reference,
      description: dto.description,
      callbackUrl,
      env: config.isSandbox ? 'sandbox' : 'production',
    });

    const checkoutId = result.CheckoutRequestID;

    if (checkoutId) {
      const log = this.logRepo.create({
        tenantId: device.tenantId,
        checkoutRequestId: checkoutId,
        amount: dto.amount,
        phone: dto.phone,
        status: 'initiated',
      });
      await this.logRepo.save(log);
    }

    return result;
  }

  // ── Safaricom callback ───────────────────────────────────────

  @Post('callback')
  @HttpCode(HttpStatus.OK)
  async callback(@Body() body: any) {
    const { Body: callbackBody } = body;
    if (!callbackBody?.stkCallback) {
      return { ResultCode: 1, ResultDesc: 'Invalid callback' };
    }

    const { ResultCode, ResultDesc, CheckoutRequestID, CallbackMetadata } = callbackBody.stkCallback;

    if (ResultCode === 0 && CallbackMetadata) {
      const items = CallbackMetadata.Item;
      const mpesaRef = items.find((i: any) => i.Name === 'MpesaReceiptNumber')?.Value;
      const amount = items.find((i: any) => i.Name === 'Amount')?.Value;

      await this.logRepo.update(
        { checkoutRequestId: CheckoutRequestID },
        {
          status: 'success',
          mpesaReceiptNumber: mpesaRef,
          resultDesc: ResultDesc,
        },
      );
    } else {
      await this.logRepo.update(
        { checkoutRequestId: CheckoutRequestID },
        { status: 'failed', resultDesc: ResultDesc },
      );
    }

    return { ResultCode: 0, ResultDesc: 'Accepted' };
  }

  // ── Payment status polling ───────────────────────────────────

  @Post('status')
  @HttpCode(HttpStatus.OK)
  async status(@Body() dto: { checkoutRequestId: string }) {
    const log = await this.logRepo.findOne({
      where: { checkoutRequestId: dto.checkoutRequestId },
    });

    if (!log) {
      return { paid: false, mpesaRef: null, found: false };
    }

    return {
      paid: log.status === 'success',
      mpesaRef: log.mpesaReceiptNumber || null,
      found: true,
    };
  }

  // ── Test connection ──────────────────────────────────────────

  @Post('test-connection')
  @HttpCode(HttpStatus.OK)
  async testConnection(@CurrentDevice() device: any) {
    const config = await this.configRepo.findOne({
      where: { tenantId: device.tenantId },
    });
    if (!config) {
      return { success: false, message: 'No M-Pesa configuration found. Save credentials first.' };
    }

    try {
      const baseUrl = config.isSandbox
        ? 'https://sandbox.safaricom.co.ke'
        : 'https://api.safaricom.co.ke';
      const consumerKey = this.encryption.decrypt(config.encryptedConsumerKey);
      const consumerSecret = this.encryption.decrypt(config.encryptedConsumerSecret);

      const { default: axios } = await import('axios');
      const creds = Buffer.from(`${consumerKey}:${consumerSecret}`).toString('base64');
      await axios.get(
        `${baseUrl}/oauth/v1/generate?grant_type=client_credentials`,
        { headers: { Authorization: `Basic ${creds}` } },
      );
      return { success: true, message: 'Credentials valid' };
    } catch (e: any) {
      return { success: false, message: e.response?.data?.errorMessage || e.message };
    }
  }
}
