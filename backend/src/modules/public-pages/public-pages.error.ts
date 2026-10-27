import { HttpException } from '@nestjs/common';

export type PublicPageErrorCode = 'PUBLIC_PAGE_NOT_FOUND' | 'PUBLIC_PAGE_INVALID' | 'PUBLIC_PAGE_NOTHING_TO_PUBLISH';

const MESSAGES: Record<PublicPageErrorCode, { status: number; message: string }> = {
  PUBLIC_PAGE_NOT_FOUND: { status: 404, message: 'Public page not found' },
  PUBLIC_PAGE_INVALID: { status: 400, message: 'Public page content is invalid' },
  PUBLIC_PAGE_NOTHING_TO_PUBLISH: { status: 409, message: 'No draft changes to publish' },
};

export function publicPageError(code: PublicPageErrorCode, details?: unknown): HttpException {
  const meta = MESSAGES[code];
  return new HttpException({ message: meta.message, errorCode: code, ...(details ? { details } : {}) }, meta.status);
}
