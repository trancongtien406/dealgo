import { Logger, Module, Optional } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { AppEnv } from '../config/env.js';
import { PlatformSettingsModule } from '../settings/platform-settings.module.js';
import { IntegrationSettingsModule } from '../integration-settings/integration-settings.module.js';
import { IntegrationSettingsService } from '../integration-settings/integration-settings.service.js';
import {
  LocalDiskObjectStorage,
  MemoryObjectStorage,
  S3ObjectStorage,
  UnavailableObjectStorage,
  type ObjectStorage,
} from '../../integrations/object-storage/index.js';
import { DocumentStoreService } from './document-store.service.js';
import { DynamicObjectStorage } from './dynamic-object-storage.js';
import { OBJECT_STORAGE } from './storage.constants.js';

export const DEFAULT_LOCAL_STORAGE_DIR = './var/object-storage';

/**
 * OBJECT_STORAGE_PROVIDER = memory | local | s3. When unset: legacy KYC_STORAGE_PROVIDER=s3
 * selects s3; otherwise test → memory, development → local disk, production → unavailable
 * (uploads answer 503 until storage is configured).
 */
export function createObjectStorage(env: {
  NODE_ENV?: string;
  OBJECT_STORAGE_PROVIDER?: string;
  OBJECT_STORAGE_LOCAL_DIR?: string;
  KYC_STORAGE_PROVIDER?: string;
  S3_ENDPOINT?: string;
  S3_REGION?: string;
  S3_BUCKET?: string;
  S3_ACCESS_KEY_ID?: string;
  S3_SECRET_ACCESS_KEY?: string;
}): ObjectStorage {
  const nodeEnv = env.NODE_ENV ?? 'development';
  const legacy = env.KYC_STORAGE_PROVIDER?.trim().toLowerCase();
  const explicit = env.OBJECT_STORAGE_PROVIDER?.trim().toLowerCase();
  const provider =
    explicit ||
    (legacy === 's3'
      ? 's3'
      : nodeEnv === 'production'
        ? 'none'
        : nodeEnv === 'test'
          ? 'memory'
          : 'local');
  switch (provider) {
    case 's3':
      return S3ObjectStorage.tryFromEnv(env) ?? new UnavailableObjectStorage();
    case 'local':
      return new LocalDiskObjectStorage(env.OBJECT_STORAGE_LOCAL_DIR?.trim() || DEFAULT_LOCAL_STORAGE_DIR);
    case 'memory':
      if (nodeEnv === 'production') {
        return new UnavailableObjectStorage();
      }
      return new MemoryObjectStorage();
    default:
      return new UnavailableObjectStorage();
  }
}

@Module({
  imports: [PlatformSettingsModule, IntegrationSettingsModule],
  providers: [
    {
      provide: OBJECT_STORAGE,
      inject: [ConfigService, { token: IntegrationSettingsService, optional: true }],
      useFactory: (
        config: ConfigService<AppEnv, true>,
        settings?: IntegrationSettingsService,
      ): ObjectStorage => {
        const storage = createObjectStorage({
          NODE_ENV: config.get('NODE_ENV', { infer: true }),
          OBJECT_STORAGE_PROVIDER: config.get('OBJECT_STORAGE_PROVIDER', { infer: true }),
          OBJECT_STORAGE_LOCAL_DIR: config.get('OBJECT_STORAGE_LOCAL_DIR', { infer: true }),
          KYC_STORAGE_PROVIDER: config.get('KYC_STORAGE_PROVIDER', { infer: true }),
          S3_ENDPOINT: config.get('S3_ENDPOINT', { infer: true }),
          S3_REGION: config.get('S3_REGION', { infer: true }),
          S3_BUCKET: config.get('S3_BUCKET', { infer: true }),
          S3_ACCESS_KEY_ID: config.get('S3_ACCESS_KEY_ID', { infer: true }),
          S3_SECRET_ACCESS_KEY: config.get('S3_SECRET_ACCESS_KEY', { infer: true }),
        });
        const unavailable = (storage as { unavailable?: boolean }).unavailable === true;
        new Logger('StorageModule').log(
          unavailable ? 'Object storage: unavailable (uploads return 503)' : `Object storage: ${storage.provider}`,
        );
        return new DynamicObjectStorage(storage, settings);
      },
    },
    DocumentStoreService,
  ],
  exports: [DocumentStoreService, OBJECT_STORAGE],
})
export class StorageModule {}
