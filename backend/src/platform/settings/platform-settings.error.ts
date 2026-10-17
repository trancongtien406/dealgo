import { HttpException } from '@nestjs/common';

export class PlatformSettingsError extends HttpException {
  constructor(
    status: number,
    readonly errorCode: string,
    message: string,
  ) {
    super({ message, errorCode }, status);
  }
}

export function settingsError(status: number, errorCode: string, message: string): PlatformSettingsError {
  return new PlatformSettingsError(status, errorCode, message);
}
