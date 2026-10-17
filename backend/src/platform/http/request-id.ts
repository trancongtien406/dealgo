import { randomUUID } from 'node:crypto';
import type { NextFunction, Request, Response } from 'express';

export const REQUEST_ID_HEADER = 'x-request-id';

export type RequestWithId = Request & { requestId?: string };

export function readOrCreateRequestId(header: string | string[] | undefined): string {
  const raw = Array.isArray(header) ? header[0] : header;
  const value = raw?.trim() ?? '';
  if (value.length >= 8 && value.length <= 128 && /^[\w.:-]+$/.test(value)) {
    return value;
  }
  return randomUUID();
}

export function requestIdMiddleware(req: RequestWithId, res: Response, next: NextFunction): void {
  const requestId = readOrCreateRequestId(req.headers[REQUEST_ID_HEADER]);
  req.requestId = requestId;
  res.setHeader(REQUEST_ID_HEADER, requestId);
  next();
}
