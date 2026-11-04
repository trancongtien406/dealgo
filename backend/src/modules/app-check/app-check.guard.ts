import {
  type CanActivate,
  type ExecutionContext,
  HttpException,
  HttpStatus,
  Injectable,
} from '@nestjs/common';
import type { Request } from 'express';
import { extractClientIp } from '../../platform/http/client-ip.decorator.js';
import { AppCheckService } from './app-check.service.js';

export const APP_CHECK_FAILED = 'APP_CHECK_FAILED';

const EXEMPT_PATHS: readonly RegExp[] = [
  /^\/health(\/.*)?$/,
  /^\/docs(-json|-yaml)?(\/.*)?$/,
  /^\/\.well-known\/.*$/,
  /^\/v1\/ops\/.*$/,
  /^\/v1\/webhooks\/.*$/,
  /^\/v1\/public\/.*$/,
  /^\/$/,
];

@Injectable()
export class AppCheckGuard implements CanActivate {
  constructor(private readonly appCheck: AppCheckService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    if (context.getType() !== 'http') {
      return true;
    }

    const req = context.switchToHttp().getRequest<Request>();
    const path = (req.originalUrl ?? req.url ?? '').split('?')[0] ?? '';

    if (EXEMPT_PATHS.some((re) => re.test(path))) {
      return true;
    }

    const header = req.headers['x-firebase-appcheck'];
    const token = typeof header === 'string' ? header : Array.isArray(header) ? header[0] : undefined;
    const clientIp = extractClientIp(req);

    const result = await this.appCheck.verifyToken(token, clientIp, path);

    if (!result.allowed) {
      throw new HttpException(
        {
          message: 'Firebase App Check validation failed',
          errorCode: APP_CHECK_FAILED,
          reason: result.reason,
        },
        HttpStatus.FORBIDDEN,
      );
    }

    return true;
  }
}

