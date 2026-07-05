import { Injectable, NestMiddleware } from '@nestjs/common';
import { Request, Response, NextFunction } from 'express';

const SENSITIVE_FIELDS = [
  'consumerKey', 'consumer_key', 'consumerSecret', 'consumer_secret',
  'passkey', 'password', 'secret', 'authorization', 'token',
];

@Injectable()
export class LogRedactionMiddleware implements NestMiddleware {
  use(req: Request, _res: Response, next: NextFunction) {
    const originalJson = _res.json.bind(_res);
    const originalSend = _res.send.bind(_res);

    _res.json = (body: any) => {
      this.redactBody(body);
      return originalJson(body);
    };

    _res.send = (body: any) => {
      if (typeof body === 'object') {
        this.redactBody(body);
      }
      return originalSend(body);
    };

    if (req.body) {
      this.redactBody(req.body);
    }

    const originalLog = console.log;
    console.log = (...args: any[]) => {
      const safe = args.map((a) => {
        if (typeof a === 'object' && a !== null) {
          const clone = JSON.parse(JSON.stringify(a));
          this.redactBody(clone);
          return clone;
        }
        return a;
      });
      originalLog.apply(console, safe);
    };

    next();
  }

  private redactBody(obj: any): void {
    if (!obj || typeof obj !== 'object') return;
    for (const key of Object.keys(obj)) {
      if (SENSITIVE_FIELDS.includes(key)) {
        obj[key] = '[REDACTED]';
      } else if (typeof obj[key] === 'object') {
        this.redactBody(obj[key]);
      }
    }
  }
}
