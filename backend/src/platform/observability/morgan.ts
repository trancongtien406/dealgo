import morgan from 'morgan';
import { Logger } from '@nestjs/common';
import type { Request, Response, RequestHandler } from 'express';
import { REQUEST_ID_HEADER, type RequestWithId } from '../http/request-id.js';

export function createMorganMiddleware(customLogger?: Logger): RequestHandler {
  const logger = customLogger ?? new Logger('HTTP');

  // Custom Morgan token for correlating HTTP requests with requestId
  morgan.token('req-id', (req: Request) => {
    return (req as RequestWithId).requestId ?? (req.headers[REQUEST_ID_HEADER] as string) ?? '-';
  });

  const format =
    process.env.NODE_ENV === 'production'
      ? '[:date[iso]] :method :url :status :res[content-length] - :response-time ms [reqId=:req-id]'
      : ':method :url :status :response-time ms - :res[content-length] [reqId=:req-id]';

  return morgan<Request, Response>(format, {
    stream: {
      write: (message: string) => logger.log(message.trim()),
    },
    skip: (req: Request) => req.url === '/health',
  });
}
