import {
  CallHandler,
  ExecutionContext,
  Injectable,
  NestInterceptor,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { map, type Observable } from 'rxjs';
import { type RequestWithId, readOrCreateRequestId, REQUEST_ID_HEADER } from './request-id.js';
import { SKIP_RESPONSE_ENVELOPE } from './skip-response-envelope.js';

type SuccessBody = {
  success: true;
  statusCode: number;
  message: string;
  data: unknown;
  requestId: string;
};

@Injectable()
export class ResponseInterceptor implements NestInterceptor {
  constructor(private readonly reflector: Reflector) {}

  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    const skip = this.reflector.getAllAndOverride<boolean>(SKIP_RESPONSE_ENVELOPE, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (skip) {
      return next.handle();
    }

    const http = context.switchToHttp();
    const request = http.getRequest<RequestWithId>();
    const response = http.getResponse<{
      statusCode?: number;
      setHeader?: (name: string, value: string) => void;
    }>();
    const requestId =
      request.requestId ?? readOrCreateRequestId(request.headers?.[REQUEST_ID_HEADER]);
    request.requestId = requestId;
    response.setHeader?.(REQUEST_ID_HEADER, requestId);

    return next.handle().pipe(
      map((data: unknown): SuccessBody => ({
        success: true,
        statusCode: response.statusCode && response.statusCode >= 100 ? response.statusCode : 200,
        message: 'OK',
        data: data ?? null,
        requestId,
      })),
    );
  }
}
