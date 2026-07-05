import { Injectable } from '@nestjs/common';
import axios from 'axios';

@Injectable()
export class MpesaService {
  async stkPush(params: {
    consumerKey: string;
    consumerSecret: string;
    passkey: string;
    shortcode: string;
    phone: string;
    amount: number;
    reference: string;
    description?: string;
    callbackUrl: string;
    env: string;
  }) {
    const baseUrl = params.env === 'production'
      ? 'https://api.safaricom.co.ke'
      : 'https://sandbox.safaricom.co.ke';

    const token = await this.getAccessToken(params.consumerKey, params.consumerSecret, baseUrl);
    const timestamp = this.getTimestamp();
    const password = Buffer.from(`${params.shortcode}${params.passkey}${timestamp}`).toString('base64');

    const response = await axios.post(
      `${baseUrl}/mpesa/stkpush/v1/processrequest`,
      {
        BusinessShortCode: params.shortcode,
        Password: password,
        Timestamp: timestamp,
        TransactionType: 'CustomerPayBillOnline',
        Amount: Math.floor(params.amount),
        PartyA: params.phone,
        PartyB: params.shortcode,
        PhoneNumber: params.phone,
        CallBackURL: params.callbackUrl,
        AccountReference: params.reference.slice(0, 12),
        TransactionDesc: params.description || 'POS Payment',
      },
      { headers: { Authorization: `Bearer ${token}` } },
    );

    return response.data;
  }

  private async getAccessToken(consumerKey: string, consumerSecret: string, baseUrl: string): Promise<string> {
    const creds = Buffer.from(`${consumerKey}:${consumerSecret}`).toString('base64');
    const res = await axios.get(
      `${baseUrl}/oauth/v1/generate?grant_type=client_credentials`,
      { headers: { Authorization: `Basic ${creds}` } },
    );
    return res.data.access_token;
  }

  private getTimestamp(): string {
    const now = new Date();
    return now.getFullYear().toString() +
      String(now.getMonth() + 1).padStart(2, '0') +
      String(now.getDate()).padStart(2, '0') +
      String(now.getHours()).padStart(2, '0') +
      String(now.getMinutes()).padStart(2, '0') +
      String(now.getSeconds()).padStart(2, '0');
  }
}
