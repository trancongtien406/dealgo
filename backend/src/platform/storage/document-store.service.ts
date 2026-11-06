import { HttpException, Inject, Injectable, Logger } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import {
  ObjectStorageUnavailableError,
  type ObjectStorage,
  type StoredObject,
} from '../../integrations/object-storage/object-storage.port.js';
import { PlatformSettingsService } from '../settings/platform-settings.service.js';
import {
  PUBLIC_IMAGE_VARIANT_WIDTHS,
  imageVariantKey,
  toPublicWebp,
  toVariantWebp,
} from './image-variants.js';
import { OBJECT_STORAGE } from './storage.constants.js';
import { UPLOAD_EXTENSIONS, sniffUploadType } from './upload-signature.js';

/** Metadata persisted (jsonb) for every stored upload; the bytes live in ObjectStorage. */
export type StoredDocumentRef = {
  key: string;
  label: string;
  contentType: string;
  sizeBytes: number;
  uploadedAt: string;
};

export type UploadInput = {
  label: string;
  contentType?: string;
  contentBase64?: string;
  /**
   * Per-file policy override set by server code only (never from a client DTO), e.g. the
   * t52u liveness clip: video types + the hard ceiling instead of the admin image policy.
   */
  policyOverride?: UploadPolicy;
};

export type UploadPolicy = {
  maxFileBytes: number;
  allowedTypes: readonly string[];
};

export function storageError(status: number, errorCode: string, message: string): HttpException {
  return new HttpException({ message, errorCode }, status);
}

const BASE64_RE = /^[A-Za-z0-9+/]*={0,2}$/;

/**
 * Public images are immutable (each upload gets its own random key), so bytes served once can be
 * reused until the object is replaced. Without this every render costs an object-storage GET,
 * which is the dominant latency when the CDN misses.
 */
const IMAGE_CACHE_MAX_BYTES = 96 * 1024 * 1024;
const IMAGE_CACHE_MAX_ENTRIES = 600;
const IMAGE_CACHE_MAX_ENTRY_BYTES = 4 * 1024 * 1024;

/**
 * Validates and stores user uploads (DEC-PROD-020). Limits come from admin settings
 * UPLOAD_MAX_FILE_KB / UPLOAD_ALLOWED_TYPES; the declared type must match the bytes.
 */
@Injectable()
export class DocumentStoreService {
  private readonly logger = new Logger(DocumentStoreService.name);
  /** Insertion-ordered LRU of rendered image bytes, keyed by `storageKey|width`. */
  private readonly imageCache = new Map<string, StoredObject>();
  private imageCacheBytes = 0;

  constructor(
    @Inject(OBJECT_STORAGE) private readonly storage: ObjectStorage,
    private readonly settings: PlatformSettingsService,
  ) {}

  get available(): boolean {
    return !(this.storage as { unavailable?: boolean }).unavailable;
  }

  async policy(): Promise<UploadPolicy> {
    const [maxKb, allowed] = await Promise.all([
      this.settings.getNumber('UPLOAD_MAX_FILE_KB'),
      this.settings.getJson<string[]>('UPLOAD_ALLOWED_TYPES'),
    ]);
    return { maxFileBytes: Math.floor(maxKb * 1024), allowedTypes: allowed };
  }

  /**
   * Decodes and checks every file first, then writes them; a bad file stores nothing.
   * Files without contentBase64 are rejected: metadata-only "documents" are not evidence.
   */
  async storeAll(prefix: string, files: readonly UploadInput[]): Promise<StoredDocumentRef[]> {
    if (files.length === 0) {
      return [];
    }
    if (!this.available) {
      throw storageError(503, 'STORAGE_UNAVAILABLE', 'File storage is not configured');
    }
    const policy = await this.policy();
    const decoded = files.map((file) => this.decode(file, file.policyOverride ?? policy));
    const uploadedAt = new Date().toISOString();
    const refs: StoredDocumentRef[] = [];
    for (const file of decoded) {
      const key = `${prefix}/${randomUUID()}.${UPLOAD_EXTENSIONS[file.contentType] ?? 'bin'}`;
      try {
        await this.storage.put(key, file.body, file.contentType);
      } catch (error) {
        this.logger.error(`Upload write failed for ${prefix}: ${(error as Error).message}`);
        throw storageError(503, 'STORAGE_UNAVAILABLE', 'Could not store the file, try again');
      }
      refs.push({
        key,
        label: file.label,
        contentType: file.contentType,
        sizeBytes: file.body.byteLength,
        uploadedAt,
      });
    }
    return refs;
  }

  /**
   * Best-effort removal of objects that no record points to any more (a failed write after
   * upload, a replaced KYC document, an old avatar). Never throws: a leftover object is a
   * storage cost, not a correctness problem, and is logged for cleanup.
   */
  async discard(refs: readonly Pick<StoredDocumentRef, 'key'>[]): Promise<void> {
    for (const ref of refs) {
      if (!isStorageKey(ref.key)) {
        continue;
      }
      for (const key of this.storageKeyWithVariants(ref.key)) {
        this.forgetImage(key);
        try {
          await this.storage.delete(key);
        } catch (error) {
          this.logger.warn(`Could not discard ${key}: ${(error as Error).message}`);
        }
      }
    }
  }

  /**
   * Stores files, runs `persist` and discards the new objects if it throws, so a failed
   * database write leaves no orphan uploads.
   */
  async storeThen<T>(
    prefix: string,
    files: readonly UploadInput[],
    persist: (refs: StoredDocumentRef[]) => Promise<T>,
  ): Promise<T> {
    const refs = await this.storeAll(prefix, files);
    try {
      return await persist(refs);
    } catch (error) {
      await this.discard(refs);
      throw error;
    }
  }

  /**
   * Same contract as `storeThen`, for images the app renders: the bytes are re-encoded to WebP
   * and a variant is written per display width, so clients download a fraction of the upload.
   */
  async storePublicThen<T>(
    prefix: string,
    files: readonly UploadInput[],
    persist: (refs: StoredDocumentRef[]) => Promise<T>,
  ): Promise<T> {
    if (files.length === 0) {
      return persist([]);
    }
    if (!this.available) {
      throw storageError(503, 'STORAGE_UNAVAILABLE', 'File storage is not configured');
    }
    const policy = await this.policy();
    const decoded = files.map((file) => this.decode(file, file.policyOverride ?? policy));
    const uploadedAt = new Date().toISOString();
    const refs: StoredDocumentRef[] = [];
    const written: string[] = [];
    try {
      for (const file of decoded) {
        const normalized = await toPublicWebp(file.body);
        const key = `${prefix}/${randomUUID()}.${normalized ? 'webp' : (UPLOAD_EXTENSIONS[file.contentType] ?? 'bin')}`;
        const body = normalized?.body ?? file.body;
        const contentType = normalized ? 'image/webp' : file.contentType;
        try {
          await this.storage.put(key, body, contentType);
        } catch (error) {
          this.logger.error(`Upload write failed for ${prefix}: ${(error as Error).message}`);
          throw storageError(503, 'STORAGE_UNAVAILABLE', 'Could not store the file, try again');
        }
        written.push(key);
        if (normalized) {
          for (const width of PUBLIC_IMAGE_VARIANT_WIDTHS) {
            if (normalized.width <= width) {
              continue;
            }
            const variantKey = imageVariantKey(key, width);
            const variant = variantKey ? await toVariantWebp(body, width) : null;
            if (!variantKey || !variant) {
              continue;
            }
            await this.storage.put(variantKey, variant, 'image/webp');
            written.push(variantKey);
          }
        }
        refs.push({
          key,
          label: file.label,
          contentType,
          sizeBytes: body.byteLength,
          uploadedAt,
        });
      }
      return await persist(refs);
    } catch (error) {
      await this.discard(written.map((key) => ({ key })));
      throw error;
    }
  }

  /**
   * Null when the bytes are missing (legacy metadata-only refs or a purged object). With a
   * `width`, the matching variant is tried first and the original is the fallback, so images
   * uploaded before variants existed still render.
   */
  async read(
    ref: Pick<StoredDocumentRef, 'key' | 'contentType'>,
    width: number | null = null,
  ): Promise<StoredObject | null> {
    if (!isStorageKey(ref.key)) {
      return null;
    }
    const variantKey = width ? imageVariantKey(ref.key, width) : null;
    try {
      if (variantKey) {
        const variant = await this.storage.get(variantKey);
        if (variant) {
          return { body: variant.body, contentType: 'image/webp' };
        }
      }
      const found = await this.storage.get(ref.key);
      return found ? { body: found.body, contentType: ref.contentType } : null;
    } catch (error) {
      if (error instanceof ObjectStorageUnavailableError) {
        throw storageError(503, 'STORAGE_UNAVAILABLE', 'File storage is not configured');
      }
      throw error;
    }
  }

  /**
   * Same lookup as `read`, for images the app renders: recently served bytes stay in process
   * memory, so repeated views of a hot photo skip object storage entirely. Only call this for
   * publicly served images — private documents must use `read`.
   */
  async readDisplayImage(
    ref: Pick<StoredDocumentRef, 'key' | 'contentType'>,
    width: number | null = null,
  ): Promise<StoredObject | null> {
    if (!isStorageKey(ref.key)) {
      return null;
    }
    const cacheKey = `${ref.key}|${width ?? 0}`;
    const cached = this.imageCache.get(cacheKey);
    if (cached) {
      this.imageCache.delete(cacheKey);
      this.imageCache.set(cacheKey, cached);
      return cached;
    }
    const found = await this.read(ref, width);
    if (found) {
      this.rememberImage(cacheKey, found);
    }
    return found;
  }

  private rememberImage(cacheKey: string, value: StoredObject): void {
    if (value.body.byteLength > IMAGE_CACHE_MAX_ENTRY_BYTES) {
      return;
    }
    const previous = this.imageCache.get(cacheKey);
    if (previous) {
      this.imageCacheBytes -= previous.body.byteLength;
      this.imageCache.delete(cacheKey);
    }
    this.imageCache.set(cacheKey, value);
    this.imageCacheBytes += value.body.byteLength;
    for (const [evictedKey, entry] of this.imageCache) {
      if (
        this.imageCacheBytes <= IMAGE_CACHE_MAX_BYTES &&
        this.imageCache.size <= IMAGE_CACHE_MAX_ENTRIES
      ) {
        break;
      }
      this.imageCache.delete(evictedKey);
      this.imageCacheBytes -= entry.body.byteLength;
    }
  }

  private forgetImage(key: string): void {
    const prefix = `${key}|`;
    for (const [cacheKey, entry] of this.imageCache) {
      if (cacheKey.startsWith(prefix)) {
        this.imageCache.delete(cacheKey);
        this.imageCacheBytes -= entry.body.byteLength;
      }
    }
  }

  private storageKeyWithVariants(key: string): string[] {
    const variants = PUBLIC_IMAGE_VARIANT_WIDTHS.map((width) =>
      imageVariantKey(key, width),
    ).filter((variant): variant is string => Boolean(variant));
    return [key, ...variants];
  }

  private decode(
    file: UploadInput,
    policy: UploadPolicy,
  ): { label: string; contentType: string; body: Buffer } {
    const label = file.label.trim().slice(0, 160);
    const raw = (file.contentBase64 ?? '').replace(/\s+/g, '');
    if (!label || raw.length === 0 || !BASE64_RE.test(raw)) {
      throw storageError(400, 'UPLOAD_INVALID', 'Each file needs a label and base64 content');
    }
    const approxBytes = Math.floor((raw.length * 3) / 4);
    if (approxBytes > policy.maxFileBytes + 2) {
      throw storageError(413, 'UPLOAD_TOO_LARGE', `File exceeds ${policy.maxFileBytes} bytes`);
    }
    const body = Buffer.from(raw, 'base64');
    if (body.byteLength === 0) {
      throw storageError(400, 'UPLOAD_INVALID', 'File is empty');
    }
    if (body.byteLength > policy.maxFileBytes) {
      throw storageError(413, 'UPLOAD_TOO_LARGE', `File exceeds ${policy.maxFileBytes} bytes`);
    }
    const sniffed = sniffUploadType(body);
    if (!sniffed || !policy.allowedTypes.includes(sniffed)) {
      throw storageError(415, 'UPLOAD_TYPE_NOT_ALLOWED', 'File type is not accepted');
    }
    const declared = file.contentType?.trim().toLowerCase();
    if (declared && declared !== sniffed && !(declared === 'image/jpg' && sniffed === 'image/jpeg')) {
      throw storageError(415, 'UPLOAD_TYPE_MISMATCH', 'File content does not match its type');
    }
    return { label, contentType: sniffed, body };
  }
}

/** Refs written before DEC-PROD-020 used `mock://` or `s3://` URIs with no stored bytes. */
function isStorageKey(key: string): boolean {
  return !key.includes('://');
}
