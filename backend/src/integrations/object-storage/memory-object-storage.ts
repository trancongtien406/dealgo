import {
  assertSafeObjectKey,
  type ListedObject,
  type ObjectStorage,
  type StoredObject,
} from './object-storage.port.js';

/** In-process storage for tests; contents vanish on restart. */
export class MemoryObjectStorage implements ObjectStorage {
  readonly provider = 'memory' as const;
  private readonly objects = new Map<string, StoredObject & { lastModified: Date }>();

  async put(key: string, body: Buffer, contentType: string): Promise<void> {
    assertSafeObjectKey(key);
    this.objects.set(key, { body: Buffer.from(body), contentType, lastModified: new Date() });
  }

  async get(key: string): Promise<StoredObject | null> {
    assertSafeObjectKey(key);
    const found = this.objects.get(key);
    return found ? { body: Buffer.from(found.body), contentType: found.contentType } : null;
  }

  async delete(key: string): Promise<void> {
    assertSafeObjectKey(key);
    this.objects.delete(key);
  }

  async *list(prefix: string): AsyncIterable<ListedObject> {
    assertSafeObjectKey(prefix);
    // Snapshot first: callers may delete while iterating.
    for (const [key, value] of Array.from(this.objects.entries())) {
      if (key.startsWith(`${prefix}/`)) {
        yield { key, lastModified: value.lastModified };
      }
    }
  }

  /** Tests: pretend an object was written at `at`. */
  setLastModified(key: string, at: Date): void {
    const found = this.objects.get(key);
    if (found) {
      found.lastModified = at;
    }
  }

  has(key: string): boolean {
    return this.objects.has(key);
  }

  get size(): number {
    return this.objects.size;
  }
}
