import { HttpException } from '@nestjs/common';

export function partnerError(status: number, errorCode: string, message: string): HttpException {
  return new HttpException({ message, errorCode }, status);
}
