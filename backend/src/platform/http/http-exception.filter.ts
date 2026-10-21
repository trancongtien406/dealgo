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
  /** Machine-readable extras, only when the thrower attached a `details` object. */
  details?: Record<string, unknown>;
};

const STATUS_ERROR_CODES: Readonly<Record<number, string>> = {
  [HttpStatus.BAD_REQUEST]: 'BAD_REQUEST',
  [HttpStatus.UNAUTHORIZED]: 'UNAUTHORIZED',
  [HttpStatus.FORBIDDEN]: 'FORBIDDEN',
  [HttpStatus.NOT_FOUND]: 'NOT_FOUND',
  [HttpStatus.CONFLICT]: 'CONFLICT',
  [HttpStatus.PAYLOAD_TOO_LARGE]: 'PAYLOAD_TOO_LARGE',
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

    if (!(exception instanceof HttpException) && readBodyParserStatus(exception) === null) {
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
      const details = readDetails(exception);
      return {
        success: false,
        statusCode,
        message,
        errorCode,
        timestamp,
        path,
        requestId,
        ...(details ? { details } : {}),
      };
    }

    const parserStatus = readBodyParserStatus(exception);
    if (parserStatus !== null) {
      return {
        success: false,
        statusCode: parserStatus,
        message:
          parserStatus === HttpStatus.PAYLOAD_TOO_LARGE
            ? 'Request body is too large'
            : 'Request body could not be parsed',
        errorCode: errorCodeForStatus(parserStatus),
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

function readDetails(exception: HttpException): Record<string, unknown> | undefined {
  const response = exception.getResponse();
  if (typeof response !== 'object' || response === null) {
    return undefined;
  }
  const details = (response as { details?: unknown }).details;
  if (typeof details !== 'object' || details === null || Array.isArray(details)) {
    return undefined;
  }
  return details as Record<string, unknown>;
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

/**
 * Express body-parser rejects oversized or malformed bodies before Nest sees the request.
 * Its errors are client errors (http-errors: `expose`, 4xx `status`, `type`), not 500s.
 */
function readBodyParserStatus(exception: unknown): number | null {
  if (!(exception instanceof Error)) {
    return null;
  }
  const candidate = exception as Error & { expose?: unknown; status?: unknown; type?: unknown };
  if (
    candidate.expose === true &&
    typeof candidate.type === 'string' &&
    typeof candidate.status === 'number' &&
    candidate.status >= 400 &&
    candidate.status < 500
  ) {
    return candidate.status;
  }
  return null;
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
