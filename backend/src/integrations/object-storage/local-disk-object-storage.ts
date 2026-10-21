import { mkdir, readdir, readFile, rename, rm, stat, writeFile } from 'node:fs/promises';
import { dirname, relative, resolve, sep } from 'node:path';
import {
  assertSafeObjectKey,
  type ListedObject,
  type ObjectStorage,
  type StoredObject,
} from './object-storage.port.js';

/**
 * Dev / single-instance storage on local disk. Each object is written next to a
 * `<key>.meta.json` sidecar holding its content type. Not for multi-instance production.
 */
export class LocalDiskObjectStorage implements ObjectStorage {
  readonly provider = 'local' as const;
  private readonly root: string;

  constructor(rootDir: string) {
    this.root = resolve(rootDir);
  }

  async put(key: string, body: Buffer, contentType: string): Promise<void> {
    const path = this.pathFor(key);
    await mkdir(dirname(path), { recursive: true });
    const tmp = `${path}.${process.pid}.${Date.now()}.tmp`;
    await writeFile(tmp, body, { mode: 0o600 });
    await rename(tmp, path);
    await writeFile(`${path}.meta.json`, JSON.stringify({ contentType }), { mode: 0o600 });
  }

  async get(key: string): Promise<StoredObject | null> {
    const path = this.pathFor(key);
    try {
      const [body, meta] = await Promise.all([
        readFile(path),
        readFile(`${path}.meta.json`, 'utf8').catch(() => '{}'),
      ]);
      const parsed = JSON.parse(meta) as { contentType?: unknown };
      return {
        body,
        contentType:
          typeof parsed.contentType === 'string' ? parsed.contentType : 'application/octet-stream',
      };
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code === 'ENOENT') {
        return null;
      }
      throw error;
    }
  }

  async delete(key: string): Promise<void> {
    const path = this.pathFor(key);
    await Promise.all([rm(path, { force: true }), rm(`${path}.meta.json`, { force: true })]);
  }

  async *list(prefix: string): AsyncIterable<ListedObject> {
    const base = this.pathFor(prefix);
    const pending = [base];
    while (pending.length > 0) {
      const dir = pending.pop()!;
      let entries;
      try {
        entries = await readdir(dir, { withFileTypes: true });
      } catch (error) {
        if ((error as NodeJS.ErrnoException).code === 'ENOENT') {
          continue;
        }
        throw error;
      }
      for (const entry of entries) {
        const path = resolve(dir, entry.name);
        if (entry.isDirectory()) {
          pending.push(path);
          continue;
        }
        // Sidecars and half-written temp files are not objects of their own.
        if (!entry.isFile() || entry.name.endsWith('.meta.json') || entry.name.endsWith('.tmp')) {
          continue;
        }
        const key = relative(this.root, path).split(sep).join('/');
        const info = await stat(path).catch(() => null);
        if (info) {
          yield { key, lastModified: info.mtime };
        }
      }
    }
  }

  private pathFor(key: string): string {
    assertSafeObjectKey(key);
    const path = resolve(this.root, key);
    if (!path.startsWith(this.root + sep)) {
      throw new Error(`Unsafe object key: ${key}`);
    }
    return path;
  }
}
