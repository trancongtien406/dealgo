import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';
import { LocalDiskObjectStorage } from '../../integrations/object-storage/local-disk-object-storage.js';
import { MemoryObjectStorage } from '../../integrations/object-storage/memory-object-storage.js';
import {
  UnavailableObjectStorage,
  assertSafeObjectKey,
} from '../../integrations/object-storage/object-storage.port.js';
import { S3ObjectStorage } from '../../integrations/object-storage/s3-object-storage.js';
import { createObjectStorage } from './storage.module.js';
import {
  TINY_JPEG_BASE64,
  TINY_PDF_BASE64,
  TINY_PNG_BASE64,
  createTestDocumentStore,
} from './testing.js';
import { sniffUploadType } from './upload-signature.js';

describe('DocumentStoreService', () => {
  it('stores verified files under the prefix and reads them back', async () => {
    const { store, storage } = createTestDocumentStore();
    const refs = await store.storeAll('partner-applications/app-1', [
      { label: 'ID front', contentType: 'image/jpeg', contentBase64: TINY_JPEG_BASE64 },
      { label: 'Licence', contentBase64: TINY_PDF_BASE64 },
    ]);
    expect(refs).toHaveLength(2);
    expect(refs[0]!.key).toMatch(/^partner-applications\/app-1\/[0-9a-f-]{36}\.jpg$/);
    expect(refs[1]).toMatchObject({ contentType: 'application/pdf', label: 'Licence' });
    expect(storage.size).toBe(2);
    const back = await store.read(refs[0]!);
    expect(back?.body.toString('base64')).toBe(TINY_JPEG_BASE64);
  });

  it('enforces the admin size and type settings before writing anything', async () => {
    const { store, storage } = createTestDocumentStore({ maxFileKb: 100, allowedTypes: ['image/jpeg'] });
    const big = Buffer.concat([Buffer.from(TINY_JPEG_BASE64, 'base64'), Buffer.alloc(110 * 1024)]);
    await expect(
      store.storeAll('p', [
        { label: 'ok', contentBase64: TINY_JPEG_BASE64 },
        { label: 'big', contentBase64: big.toString('base64') },
      ]),
    ).rejects.toMatchObject({ status: 413, response: { errorCode: 'UPLOAD_TOO_LARGE' } });
    await expect(
      store.storeAll('p', [{ label: 'png', contentBase64: TINY_PNG_BASE64 }]),
    ).rejects.toMatchObject({ status: 415, response: { errorCode: 'UPLOAD_TYPE_NOT_ALLOWED' } });
    await expect(
      store.storeAll('p', [{ label: 'txt', contentBase64: Buffer.from('hello world').toString('base64') }]),
    ).rejects.toMatchObject({ status: 415 });
    await expect(
      store.storeAll('p', [{ label: 'bad', contentBase64: '***' }]),
    ).rejects.toMatchObject({ status: 400 });
    expect(storage.size).toBe(0);
  });

  it('answers 503 when storage is unavailable and returns null for legacy refs', async () => {
    const { store } = createTestDocumentStore();
    expect(await store.read({ key: 'mock://partner-applications/x/0-id', contentType: 'image/jpeg' })).toBeNull();
    const unavailable = new (store.constructor as never as new (...args: unknown[]) => typeof store)(
      new UnavailableObjectStorage(),
      {} as never,
    );
    await expect(
      unavailable.storeAll('p', [{ label: 'x', contentBase64: TINY_JPEG_BASE64 }]),
    ).rejects.toMatchObject({ status: 503 });
  });
});

describe('object storage adapters', () => {
  it('local disk writes, reads and refuses path traversal', async () => {
    const dir = await mkdtemp(join(tmpdir(), 'dealgo-storage-'));
    try {
      const storage = new LocalDiskObjectStorage(dir);
      await storage.put('a/b/file.jpg', Buffer.from([1, 2, 3]), 'image/jpeg');
      const read = await storage.get('a/b/file.jpg');
      expect(read).toEqual({ body: Buffer.from([1, 2, 3]), contentType: 'image/jpeg' });
      expect(await storage.get('a/missing.jpg')).toBeNull();
      await expect(storage.get('../etc/passwd')).rejects.toThrow(/Unsafe/);
    } finally {
      await rm(dir, { recursive: true, force: true });
    }
  });

  it('rejects unsafe keys', () => {
    for (const key of ['', '/abs', 'a//b', 'a/../b', 'a\\b', 'a b']) {
      expect(() => assertSafeObjectKey(key)).toThrow();
    }
    expect(() => assertSafeObjectKey('partner-applications/x/1.jpg')).not.toThrow();
  });

  it('selects the provider from env with safe defaults', () => {
    expect(createObjectStorage({ NODE_ENV: 'test' })).toBeInstanceOf(MemoryObjectStorage);
    expect(createObjectStorage({ NODE_ENV: 'development' })).toBeInstanceOf(LocalDiskObjectStorage);
    expect(createObjectStorage({ NODE_ENV: 'development', KYC_STORAGE_PROVIDER: 'mock' })).toBeInstanceOf(
      LocalDiskObjectStorage,
    );
    expect(createObjectStorage({ NODE_ENV: 'production' })).toBeInstanceOf(UnavailableObjectStorage);
    expect(
      createObjectStorage({ NODE_ENV: 'production', OBJECT_STORAGE_PROVIDER: 'memory' }),
    ).toBeInstanceOf(UnavailableObjectStorage);
    expect(createObjectStorage({ NODE_ENV: 'production', OBJECT_STORAGE_PROVIDER: 's3' })).toBeInstanceOf(
      UnavailableObjectStorage,
    );
    expect(
      createObjectStorage({
        NODE_ENV: 'production',
        KYC_STORAGE_PROVIDER: 's3',
        S3_ENDPOINT: 'https://s3.example.com',
        S3_REGION: 'auto',
        S3_BUCKET: 'b',
        S3_ACCESS_KEY_ID: 'k',
        S3_SECRET_ACCESS_KEY: 's',
      }),
    ).toBeInstanceOf(S3ObjectStorage);
  });

  it('sniffs supported signatures only', () => {
    expect(sniffUploadType(Buffer.from(TINY_JPEG_BASE64, 'base64'))).toBe('image/jpeg');
    expect(sniffUploadType(Buffer.from(TINY_PNG_BASE64, 'base64'))).toBe('image/png');
    expect(sniffUploadType(Buffer.from(TINY_PDF_BASE64, 'base64'))).toBe('application/pdf');
    expect(sniffUploadType(Buffer.from('RIFF0000WEBPVP8 ', 'latin1'))).toBe('image/webp');
    expect(sniffUploadType(Buffer.from('<svg/>'))).toBeNull();
  });
  it('storeThen discards stored files when the database write fails (no orphans)', async () => {
    const { store, storage } = createTestDocumentStore();
    await expect(
      store.storeThen('t', [{ label: 'a', contentBase64: TINY_JPEG_BASE64 }], async () => {
        throw new Error('db down');
      }),
    ).rejects.toThrow('db down');
    expect(storage.size).toBe(0);
    const kept = await store.storeThen('t', [{ label: 'a', contentBase64: TINY_JPEG_BASE64 }], async (refs) => refs);
    expect(storage.size).toBe(1);
    await store.discard([...kept, { key: 'mock://legacy' }, { key: 't/missing.jpg' }]);
    expect(storage.size).toBe(0);
  });

  it('local disk delete removes the object and its sidecar', async () => {
    const dir = await mkdtemp(join(tmpdir(), 'dg-del-'));
    try {
      const disk = new LocalDiskObjectStorage(dir);
      await disk.put('a/b.jpg', Buffer.from(TINY_JPEG_BASE64, 'base64'), 'image/jpeg');
      await disk.delete('a/b.jpg');
      expect(await disk.get('a/b.jpg')).toBeNull();
      await disk.delete('a/b.jpg');
    } finally {
      await rm(dir, { recursive: true, force: true });
    }
  });
});
