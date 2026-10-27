import { describe, expect, it, vi } from 'vitest';
import type { PrismaService } from '../platform/database/prisma.service.js';
import type { PlatformSettingsService } from '../platform/settings/platform-settings.service.js';
import { ChatRetentionService } from './chat-retention.service.js';

describe('ChatRetentionService (DEC-PROD-056)', () => {
  it('deletes messages older than CHAT_RETENTION_DAYS', async () => {
    const findMany = vi.fn().mockResolvedValueOnce([{ id: 'a' }, { id: 'b' }]);
    const deleteMany = vi.fn(async () => ({ count: 2 }));
    const prisma = { db: () => ({ chatMessage: { findMany, deleteMany } }) } as unknown as PrismaService;
    const settings = { getNumber: async () => 90 } as unknown as PlatformSettingsService;
    const now = new Date('2026-10-26T00:00:00.000Z');

    await expect(new ChatRetentionService(prisma, settings).runOnce(now)).resolves.toBe(2);
    expect(findMany).toHaveBeenCalledWith(
      expect.objectContaining({ where: { createdAt: { lt: new Date('2026-07-28T00:00:00.000Z') } } }),
    );
    expect(deleteMany).toHaveBeenCalledWith({ where: { id: { in: ['a', 'b'] } } });
  });

  it('is a no-op without a database', async () => {
    const prisma = { db: () => null } as unknown as PrismaService;
    await expect(new ChatRetentionService(prisma, {} as PlatformSettingsService).runOnce()).resolves.toBe(0);
  });
});
