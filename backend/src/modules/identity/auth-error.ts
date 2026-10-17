import { HttpException } from '@nestjs/common';

export function authError(status: number, errorCode: string, message: string): HttpException {
  return new HttpException({ message, errorCode }, status);
}
