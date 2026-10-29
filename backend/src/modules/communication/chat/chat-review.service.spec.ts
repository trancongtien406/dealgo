import { ConfigService } from '@nestjs/config';
import { describe, expect, it, vi } from 'vitest';
import { loadEnv, type AppEnv } from '../../../platform/config/env.js';
import type { PrismaService } from '../../../platform/database/prisma.service.js';
import type { PlatformSettingsService } from '../../../platform/settings/platform-settings.service.js';
import { chatAad, chatCipherFromEnv } from './chat-cipher.js';
import { ChatReviewService } from './chat-review.service.js';

const KEY = Buffer.alloc(32, 9).toString('base64');
const config = new ConfigService<AppEnv, true>(loadEnv({ NODE_ENV: 'test', CHAT_ENCRYPTION_KEY: KEY }));
const settings = { getNumber: async () => 90 } as unknown as PlatformSettingsService;

function build(opts: { ride?: boolean; thread?: boolean } = {}) {
  const cipher = chatCipherFromEnv({ CHAT_ENCRYPTION_KEY: KEY })!;
  const sealed = cipher.encrypt('xin chào tài xế', chatAad('m1', 't1'));
  const calls: string[] = [];
  const auditCreate = vi.fn(async () => {
    calls.push('audit');
    return {};
  });
  const db = {
    ride: { findUnique: vi.fn(async () => (opts.ride === false ? null : { customerId: 'cust' })) },
    foodOrder: { findUnique: vi.fn(async () => ({ customerId: 'cust' })) },
    chatThread: { findMany: vi.fn(async () => (opts.thread === false ? [] : [{ id: 't1', channel: 'DRIVER' }])) },
    opsAuditLog: { create: auditCreate },
    chatMessage: {
      findMany: vi.fn(async () => {
        calls.push('read');
        return [
          { id: 'm1', threadId: 't1', senderUserId: 'cust', body: null, bodyCiphertext: sealed.ciphertext, keyVersion: sealed.keyVersion, createdAt: new Date('2026-10-26T01:00:00Z'), sender: { displayName: 'An' } },
          { id: 'm2', threadId: 't1', senderUserId: 'drv', body: 'ok', bodyCiphertext: null, keyVersion: null, createdAt: new Date('2026-10-26T01:01:00Z'), sender: { displayName: 'Bình' } },
        ];
      }),
    },
  };
  const prisma = { db: () => db } as unknown as PrismaService;
  return { service: new ChatReviewService(prisma, config, settings), auditCreate, calls };
}

describe('ChatReviewService (DEC-PROD-056)', () => {
  it('audits first, then returns decrypted messages with sender roles', async () => {
    const { service, auditCreate, calls } = build();
    const result = await service.review({ kind: 'ride', id: 'ride-1', reason: 'Khiếu nại hành vi tài xế', ticketId: 'tk-1' }, 'ops-1');
    expect(calls).toEqual(['audit', 'read']);
    expect(auditCreate).toHaveBeenCalledWith({
      data: expect.objectContaining({
        actorUserId: 'ops-1',
        action: 'CHAT_REVIEW',
        entityType: 'CHAT_THREAD',
        entityId: 't1',
        reason: 'Khiếu nại hành vi tài xế',
        metadata: { kind: 'ride', targetId: 'ride-1', ticketId: 'tk-1', threadIds: ['t1'] },
      }),
    });
    expect(result.retentionDays).toBe(90);
    expect(result.messages.map((m) => [m.senderRole, m.body])).toEqual([
      ['CUSTOMER', 'xin chào tài xế'],
      ['PARTNER', 'ok'],
    ]);
  });

  it('404s for an unknown ride and returns an empty, still-audited result without a thread', async () => {
    await expect(build({ ride: false }).service.review({ kind: 'ride', id: 'x', reason: 'reason' }, 'ops')).rejects.toMatchObject({
      response: { errorCode: 'CHAT_NOT_FOUND' },
    });
    const { service, auditCreate } = build({ thread: false });
    await expect(service.review({ kind: 'food', id: 'o1', reason: 'reason' }, 'ops')).resolves.toMatchObject({
      threadId: null,
      messages: [],
    });
    expect(auditCreate).toHaveBeenCalledTimes(1);
  });
});
