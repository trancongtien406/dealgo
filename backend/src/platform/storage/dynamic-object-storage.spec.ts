import { describe, expect, it, vi } from 'vitest';
import { DynamicObjectStorage } from './dynamic-object-storage.js';
import type { IntegrationSettingsService } from '../integration-settings/integration-settings.service.js';
import { MemoryObjectStorage } from '../../integrations/object-storage/memory-object-storage.js';

describe('DynamicObjectStorage', () => {
  it('falls back to env storage when settings service is missing or unconfigured', async () => {
    const memory = new MemoryObjectStorage();
    const dynamic = new DynamicObjectStorage(memory);

    await dynamic.put('test.txt', Buffer.from('hello'), 'text/plain');
    const stored = await dynamic.get('test.txt');
    expect(stored?.body.toString()).toBe('hello');
    expect(dynamic.has('test.txt')).toBe(true);

    await dynamic.delete('test.txt');
    expect(await dynamic.get('test.txt')).toBeNull();
    expect(dynamic.has('test.txt')).toBe(false);
  });

  it('resolves local storage from IntegrationSettings', async () => {
    const memory = new MemoryObjectStorage();
    const mockSettings: Partial<IntegrationSettingsService> = {
      values: vi.fn(async () => ({
        config: { provider: 'local', localDir: '/tmp/dealgo-test-storage' },
        secrets: {},
        updatedAt: null,
        updatedByUserId: null,
      })) as any,
    };

    const dynamic = new DynamicObjectStorage(memory, mockSettings as IntegrationSettingsService);
    expect(dynamic.provider).toBe('memory');
    // Calling resolveStorage happens on operations
    expect(mockSettings.values).not.toHaveBeenCalled();
    // After calling put/get, it queries 'STORAGE'
    await dynamic.get('file.txt').catch(() => null);
    expect(mockSettings.values).toHaveBeenCalledWith('STORAGE');
  });

  it('resolves S3 and R2 configurations from IntegrationSettings', async () => {
    const memory = new MemoryObjectStorage();
    const mockSettings: Partial<IntegrationSettingsService> = {
      values: vi.fn(async () => ({
        config: {
          provider: 'r2',
          accountId: 'cf-acc-123',
          bucket: 'my-bucket',
        },
        secrets: {
          accessKeyId: 'r2-key',
          secretAccessKey: 'r2-secret',
        },
        updatedAt: null,
        updatedByUserId: null,
      })) as any,
    };

    const dynamic = new DynamicObjectStorage(memory, mockSettings as IntegrationSettingsService);
    await dynamic.get('file.txt').catch(() => null);
    expect(mockSettings.values).toHaveBeenCalledWith('STORAGE');
  });
});

