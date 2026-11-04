import { Logger } from '@nestjs/common';
import type { IntegrationSettingsService } from '../integration-settings/integration-settings.service.js';
import {
  LocalDiskObjectStorage,
  S3ObjectStorage,
  type ListedObject,
  type ObjectStorage,
  type ObjectStorageProvider,
  type StoredObject,
} from '../../integrations/object-storage/index.js';
import { DEFAULT_LOCAL_STORAGE_DIR } from './storage.module.js';

/**
 * Dynamic ObjectStorage that resolves its adapter per request from IntegrationSettings (DB)
 * with transparent fallback to env-configured storage.
 * Supports:
 * - 'r2': Cloudflare R2 (S3-compatible)
 * - 's3': AWS S3
 * - 'local': Local disk storage (default ./var/object-storage)
 */
export class DynamicObjectStorage implements ObjectStorage {
  private readonly logger = new Logger(DynamicObjectStorage.name);

  constructor(
    private readonly envStorage: ObjectStorage,
    private readonly settings?: IntegrationSettingsService,
  ) {}

  get provider(): ObjectStorageProvider {
    return this.envStorage.provider;
  }

  private async resolveStorage(): Promise<ObjectStorage> {
    if (!this.settings) {
      return this.envStorage;
    }
    try {
      const values = await this.settings.values('STORAGE');
      const provider = values.config.provider?.trim().toLowerCase();
      if (!provider) {
        return this.envStorage;
      }

      if (provider === 'local') {
        const localDir = values.config.localDir?.trim() || DEFAULT_LOCAL_STORAGE_DIR;
        return new LocalDiskObjectStorage(localDir);
      }

      if (provider === 'r2' || provider === 's3') {
        const accountId = values.config.accountId?.trim();
        const endpoint =
          values.config.endpoint?.trim() ||
          (accountId ? `https://${accountId}.r2.cloudflarestorage.com` : '');
        const region = values.config.region?.trim() || (provider === 'r2' ? 'auto' : 'us-east-1');
        const bucket = values.config.bucket?.trim();
        const accessKeyId = values.secrets.accessKeyId?.trim();
        const secretAccessKey = values.secrets.secretAccessKey?.trim();

        if (endpoint && bucket && accessKeyId && secretAccessKey) {
          return new S3ObjectStorage({
            endpoint,
            region,
            bucket,
            accessKeyId,
            secretAccessKey,
          });
        }
      }
    } catch (err) {
      this.logger.warn(`Could not resolve storage from integration settings: ${err}`);
    }

    return this.envStorage;
  }

  async put(key: string, body: Buffer, contentType: string): Promise<void> {
    const storage = await this.resolveStorage();
    return storage.put(key, body, contentType);
  }

  async get(key: string): Promise<StoredObject | null> {
    const storage = await this.resolveStorage();
    return storage.get(key);
  }

  async delete(key: string): Promise<void> {
    const storage = await this.resolveStorage();
    return storage.delete(key);
  }

  has(key: string): boolean {
    if ('has' in (this.envStorage as any) && typeof (this.envStorage as any).has === 'function') {
      return (this.envStorage as any).has(key);
    }
    return false;
  }

  async *list(prefix: string): AsyncIterable<ListedObject> {
    const storage = await this.resolveStorage();
    yield* storage.list(prefix);
  }
}
