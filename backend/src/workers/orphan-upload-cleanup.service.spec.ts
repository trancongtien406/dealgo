import { mkdtemp, rm, utimes } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { LocalDiskObjectStorage } from '../integrations/object-storage/local-disk-object-storage.js';
import { MemoryObjectStorage } from '../integrations/object-storage/memory-object-storage.js';
import { UnavailableObjectStorage } from '../integrations/object-storage/object-storage.port.js';
import type { PlatformSettingsService } from '../platform/settings/platform-settings.service.js';
import {
  ORPHAN_MAX_DELETES_PER_RUN,
  OrphanUploadCleanupService,
} from './orphan-upload-cleanup.service.js';

const NOW = new Date('2026-10-19T12:00:00.000Z');
const hoursAgo = (h: number) => new Date(NOW.getTime() - h * 3_600_000);

function settings(hours: number): PlatformSettingsService {
  return { getNumber: async () => hours } as unknown as PlatformSettingsService;
}

async function seed(storage: MemoryObjectStorage, key: string, ageHours: number) {
  await storage.put(key, Buffer.from('x'), 'image/jpeg');
  storage.setLastModified(key, hoursAgo(ageHours));
}

describe('OrphanUploadCleanupService (DEC-PROD-022)', () => {
  it('deletes only old files no record points to, inside the upload prefixes', async () => {
    const storage = new MemoryObjectStorage();
    await seed(storage, 'partner-applications/a1/kept.jpg', 500);
    await seed(storage, 'partner-applications/a1/orphan.jpg', 100);
    await seed(storage, 'support-attachments/2026-10/fresh.jpg', 2);
    await seed(storage, 'avatars/u1/old.jpg', 200);
    await seed(storage, 'avatars/u1/current.jpg', 200);
    await seed(storage, 'other-prefix/untouched.jpg', 900);
    const refs = { referencedKeys: async () => new Set(['partner-applications/a1/kept.jpg', 'avatars/u1/current.jpg']) };
    const svc = new OrphanUploadCleanupService(storage, refs, settings(72));

    const report = await svc.runOnce(NOW);

    expect(report).toMatchObject({ ran: true, maxAgeHours: 72, scanned: 5, referenced: 2, tooYoung: 1, deleted: 2 });
    expect(storage.has('partner-applications/a1/orphan.jpg')).toBe(false);
    expect(storage.has('avatars/u1/old.jpg')).toBe(false);
    expect(storage.has('partner-applications/a1/kept.jpg')).toBe(true);
    expect(storage.has('avatars/u1/current.jpg')).toBe(true);
    expect(storage.has('support-attachments/2026-10/fresh.jpg')).toBe(true);
    expect(storage.has('other-prefix/untouched.jpg')).toBe(true);
  });

  it('never goes below the 24 h floor even if the setting is lower', async () => {
    const storage = new MemoryObjectStorage();
    await seed(storage, 'support-attachments/2026-10/a.jpg', 10);
    const svc = new OrphanUploadCleanupService(storage, { referencedKeys: async () => new Set() }, settings(1));
    const report = await svc.runOnce(NOW);
    expect(report).toMatchObject({ ran: true, maxAgeHours: 24, deleted: 0, tooYoung: 1 });
  });

  it('does nothing without a database or storage, and when references cannot be read', async () => {
    const storage = new MemoryObjectStorage();
    await seed(storage, 'avatars/u1/a.jpg', 999);
    expect(
      await new OrphanUploadCleanupService(storage, { referencedKeys: async () => null }, settings(72)).runOnce(NOW),
    ).toEqual({ ran: false, reason: 'no-database' });
    expect(
      await new OrphanUploadCleanupService(
        new UnavailableObjectStorage(),
        { referencedKeys: async () => new Set() },
        settings(72),
      ).runOnce(NOW),
    ).toEqual({ ran: false, reason: 'storage-unavailable' });
    const failing = new OrphanUploadCleanupService(
      storage,
      { referencedKeys: async () => Promise.reject(new Error('db down')) },
      settings(72),
    );
    await expect(failing.runOnce(NOW)).rejects.toThrow('db down');
    expect(storage.has('avatars/u1/a.jpg')).toBe(true);
  });

  it('caps deletions per run', async () => {
    const storage = new MemoryObjectStorage();
    for (let i = 0; i < ORPHAN_MAX_DELETES_PER_RUN + 3; i += 1) {
      await seed(storage, `support-attachments/2026-01/${i}.jpg`, 1000);
    }
    const svc = new OrphanUploadCleanupService(storage, { referencedKeys: async () => new Set() }, settings(72));
    const report = await svc.runOnce(NOW);
    expect(report).toMatchObject({ deleted: ORPHAN_MAX_DELETES_PER_RUN, capped: true });
    expect(storage.size).toBe(3);
  });

  it('lists local-disk objects without sidecars and deletes the sidecar too', async () => {
    const root = await mkdtemp(join(tmpdir(), 'dealgo-orphan-'));
    try {
      const storage = new LocalDiskObjectStorage(root);
      await storage.put('avatars/u1/old.jpg', Buffer.from('x'), 'image/jpeg');
      await storage.put('avatars/u1/new.jpg', Buffer.from('x'), 'image/jpeg');
      const old = hoursAgo(100);
      await utimes(join(root, 'avatars/u1/old.jpg'), old, old);
      const listed = [];
      for await (const item of storage.list('avatars')) listed.push(item.key);
      expect(listed.sort()).toEqual(['avatars/u1/new.jpg', 'avatars/u1/old.jpg']);
      const empty = [];
      for await (const item of storage.list('partner-applications')) empty.push(item);
      expect(empty).toEqual([]);

      const svc = new OrphanUploadCleanupService(storage, { referencedKeys: async () => new Set() }, settings(72));
      expect(await svc.runOnce(new Date(Date.now()))).toMatchObject({ deleted: 1, tooYoung: 1 });
      expect(await storage.get('avatars/u1/old.jpg')).toBeNull();
      expect(await storage.get('avatars/u1/new.jpg')).not.toBeNull();
    } finally {
      await rm(root, { recursive: true, force: true });
    }
  });
});
