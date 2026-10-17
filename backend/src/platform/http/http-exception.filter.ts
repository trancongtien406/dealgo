import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
  Injectable,
  Logger,
} from '@nestjs/common';
import type { Response } from 'express';
import { type RequestWithId, readOrCreateRequestId, REQUEST_ID_HEADER } from './request-id.js';

type ErrorBody = {
  success: false;
  statusCode: number;
  message: string;
  errorCode: string;
  timestamp: string;
  path: string;
  requestId: string;
};

const STATUS_ERROR_CODES: Readonly<Record<number, string>> = {
  [HttpStatus.BAD_REQUEST]: 'BAD_REQUEST',
  [HttpStatus.UNAUTHORIZED]: 'UNAUTHORIZED',
  [HttpStatus.FORBIDDEN]: 'FORBIDDEN',
  [HttpStatus.NOT_FOUND]: 'NOT_FOUND',
  [HttpStatus.CONFLICT]: 'CONFLICT',
  [HttpStatus.UNPROCESSABLE_ENTITY]: 'UNPROCESSABLE_ENTITY',
  [HttpStatus.TOO_MANY_REQUESTS]: 'TOO_MANY_REQUESTS',
};

@Catch()
@Injectable()
export class HttpExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger(HttpExceptionFilter.name);

  catch(exception: unknown, host: ArgumentsHost): void {
    const http = host.switchToHttp();
    const response = http.getResponse<Response>();
    const request = http.getRequest<RequestWithId>();
    const requestId =
      request.requestId ?? readOrCreateRequestId(request.headers?.[REQUEST_ID_HEADER]);
    request.requestId = requestId;
    response.setHeader(REQUEST_ID_HEADER, requestId);
    const body = this.toErrorBody(
      exception,
      request.originalUrl || request.url || '',
      requestId,
    );

    if (!(exception instanceof HttpException)) {
      if (exception instanceof Error) {
        const sanitizedMessage = sanitizeLogMessage(exception.message);
        const sanitizedStack = exception.stack ? sanitizeLogMessage(exception.stack) : undefined;
        this.logger.error(
          `Unhandled exception: ${exception.name}: ${sanitizedMessage}`,
          sanitizedStack,
        );
      } else {
        this.logger.error(`Unhandled exception: UnknownError`);
      }
    }

    response.status(body.statusCode).json(body);
  }

  private toErrorBody(exception: unknown, path: string, requestId: string): ErrorBody {
    const timestamp = new Date().toISOString();

    if (exception instanceof HttpException) {
      const statusCode = exception.getStatus();
      const { message, errorCode } = readHttpException(exception, statusCode);
      return {
        success: false,
        statusCode,
        message,
        errorCode,
        timestamp,
        path,
        requestId,
      };
    }

    return {
      success: false,
      statusCode: HttpStatus.INTERNAL_SERVER_ERROR,
      message: 'Internal server error',
      errorCode: 'INTERNAL_SERVER_ERROR',
      timestamp,
      path,
      requestId,
    };
  }
}

function readHttpException(
  exception: HttpException,
  statusCode: number,
): { message: string; errorCode: string } {
  const response = exception.getResponse();
  if (typeof response === 'string') {
    return { message: response, errorCode: errorCodeForStatus(statusCode) };
  }

  if (typeof response === 'object' && response !== null) {
    const body = response as { message?: unknown; errorCode?: unknown };
    const message = normalizeMessage(body.message, exception.message);
    const errorCode =
      typeof body.errorCode === 'string'
        ? body.errorCode
        : Array.isArray(body.message)
          ? 'VALIDATION_ERROR'
          : errorCodeForStatus(statusCode);
    return { message, errorCode };
  }

  return { message: exception.message, errorCode: errorCodeForStatus(statusCode) };
}

function normalizeMessage(message: unknown, fallback: string): string {
  if (typeof message === 'string' && message.trim() !== '') {
    return message;
  }
  if (Array.isArray(message)) {
    const parts = message.filter((part): part is string => typeof part === 'string' && part !== '');
    if (parts.length > 0) {
      return parts.join('; ');
    }
  }
  return fallback;
}

function errorCodeForStatus(statusCode: number): string {
  return (
    STATUS_ERROR_CODES[statusCode] ??
    (statusCode >= 500 ? 'INTERNAL_SERVER_ERROR' : 'HTTP_ERROR')
  );
}

const SENSITIVE_KEY_VALUE_REGEX =
  /(?:password|passwd|pwd|secret|token|access_key|secret_key|api_key|authorization)\s*[:=]\s*(?:'[^']*'|"[^"]*"|[^\s,;&]+)/gi;
const BEARER_REGEX = /bearer\s+[a-zA-Z0-9_\-.]+/gi;
const URI_CREDENTIALS_REGEX = /((?:postgres|postgresql|mysql|mongodb|redis|amqp|smtp|https?):\/\/[^:\s]+:)[^@\s]+(@)/gi;

export function sanitizeLogMessage(input: string): string {
  return input
    .replace(SENSITIVE_KEY_VALUE_REGEX, (match) => {
      const separatorMatch = match.match(/[:=]\s*/);
      if (!separatorMatch || separatorMatch.index === undefined) {
        return '[REDACTED]';
      }
      const prefix = match.slice(0, separatorMatch.index + separatorMatch[0].length);
      return `${prefix}[REDACTED]`;
    })
    .replace(BEARER_REGEX, 'bearer [REDACTED]')
    .replace(URI_CREDENTIALS_REGEX, '$1[REDACTED]$2');
}
