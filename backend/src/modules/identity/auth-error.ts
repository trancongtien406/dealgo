import { HttpException } from '@nestjs/common';

/**
 * `details` is returned to the client as-is in the error envelope, so it must only hold
 * data the caller is allowed to see (for example a challenge id after a correct password).
 */
export function authError(
  status: number,
  errorCode: string,
  message: string,
  details?: Record<string, unknown>,
): HttpException {
  return new HttpException(details ? { message, errorCode, details } : { message, errorCode }, status);
}
