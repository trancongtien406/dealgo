import { HttpException } from '@nestjs/common';
import type { IntegrationKindName } from './integration-settings.repository.js';

export const INTEGRATION_SETTINGS_REPOSITORY = Symbol('INTEGRATION_SETTINGS_REPOSITORY');

/** Short in-process cache; API and worker each re-read within this window after an Admin change. */
export const INTEGRATION_SETTINGS_CACHE_TTL_MS = 15_000;

/** Fields an Admin may set per integration. Secret fields are encrypted and never returned. */
export const INTEGRATION_FIELDS = {
  EMAIL: {
    config: [
      'provider',
      'fromName',
      'fromAddress',
      'smtpHost',
      'smtpPort',
      'smtpUser',
      'smtpSecure',
      'sesRegion',
      'sesConfigurationSet',
      'sesSnsTopicArn',
    ],
    secrets: ['smtpPassword', 'sesAccessKeyId', 'sesSecretAccessKey'],
  },
  MAPS: {
    config: [],
    secrets: ['mapboxPublicToken', 'mapboxServerToken', 'googleMapsApiKey'],
  },
  /** Admin › Lỗi hệ thống: read access to Sentry issues (token never leaves the server). */
  SENTRY: {
    config: ['org', 'region', 'projects'],
    secrets: ['authToken'],
  },
} as const satisfies Record<IntegrationKindName, { config: readonly string[]; secrets: readonly string[] }>;

export type EmailConfigField = (typeof INTEGRATION_FIELDS.EMAIL.config)[number];
export type EmailSecretField = (typeof INTEGRATION_FIELDS.EMAIL.secrets)[number];
export type MapsSecretField = (typeof INTEGRATION_FIELDS.MAPS.secrets)[number];

export class IntegrationSettingsError extends HttpException {
  constructor(
    status: number,
    readonly errorCode: string,
    message: string,
  ) {
    super({ message, errorCode }, status);
  }
}

export function integrationError(status: number, errorCode: string, message: string): IntegrationSettingsError {
  return new IntegrationSettingsError(status, errorCode, message);
}
