export type ObjectStorageProvider = 'memory' | 'local' | 's3';

export type StoredObject = {
  body: Buffer;
  contentType: string;
};

/** One stored object as seen by a listing (no bytes). */
export type ListedObject = {
  key: string;
  lastModified: Date;
};

/**
 * Byte storage for user uploads (KYC/KYB documents, ticket attachments).
 * Keys are relative paths such as `partner-applications/<id>/<uuid>.jpg`; callers never
 * pass user input as a key without sanitising it first (see DocumentStoreService).
 */
export interface ObjectStorage {
  readonly provider: ObjectStorageProvider;
  put(key: string, body: Buffer, contentType: string): Promise<void>;
  /** Null when the object does not exist. */
  get(key: string): Promise<StoredObject | null>;
  /** Removes the object; a missing object is not an error. */
  delete(key: string): Promise<void>;
  /** Every object whose key starts with `prefix/` (used by the orphan-upload cleanup). */
  list(prefix: string): AsyncIterable<ListedObject>;
}

/** Fails every call; used when production has no storage configured (fail closed). */
export class UnavailableObjectStorage implements ObjectStorage {
  readonly provider = 'memory' as const;
  readonly unavailable = true;

  async put(): Promise<void> {
    throw new ObjectStorageUnavailableError();
  }

  async get(): Promise<StoredObject | null> {
    throw new ObjectStorageUnavailableError();
  }

  async delete(): Promise<void> {
    throw new ObjectStorageUnavailableError();
  }

  // eslint-disable-next-line require-yield
  async *list(): AsyncIterable<ListedObject> {
    throw new ObjectStorageUnavailableError();
  }
}

export class ObjectStorageUnavailableError extends Error {
  constructor() {
    super('Object storage provider is not configured');
  }
}

/** Rejects keys that could escape the storage root or address another tenant's prefix. */
export function assertSafeObjectKey(key: string): void {
  if (
    key.length === 0 ||
    key.length > 400 ||
    key.startsWith('/') ||
    key.includes('\\') ||
    key.includes('\0') ||
    key.split('/').some((part) => part === '' || part === '.' || part === '..') ||
    !/^[a-zA-Z0-9._/-]+$/.test(key)
  ) {
    throw new Error(`Unsafe object key: ${key}`);
  }
}
