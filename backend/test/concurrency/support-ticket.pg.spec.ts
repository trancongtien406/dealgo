/**
 * DEC-PROD-018: concurrent submits can never exceed the per-user open-ticket cap or the
 * per-contact daily cap. Skips when DATABASE_URL is unset.
 */
import { randomUUID } from 'node:crypto';
import { ConfigModule } from '@nestjs/config';
import { Test } from '@nestjs/testing';
import { loadEnv } from '../../src/platform/config/env.js';
import { PrismaModule } from '../../src/platform/database/prisma.module.js';
import { PrismaService } from '../../src/platform/database/prisma.service.js';
import { PrismaSupportTicketRepository } from '../../src/modules/support-ticket/support-ticket-prisma.repository.js';
import { SupportRuleError } from '../../src/modules/support-ticket/support-ticket.repository.js';

const hasDatabase = Boolean(process.env.DATABASE_URL?.trim());
const describePg = hasDatabase ? describe : describe.skip;

describePg('support ticket limits (postgres)', () => {
  let prisma: PrismaService;
  let repo: PrismaSupportTicketRepository;
  let close: () => Promise<void>;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      imports: [
        ConfigModule.forRoot({
          isGlobal: true,
          ignoreEnvFile: true,
          validate: () =>
            loadEnv({
              NODE_ENV: 'test',
              DATABASE_URL: process.env.DATABASE_URL,
              JWT_ACCESS_SECRET: 'test-access-secret',
            }),
        }),
        PrismaModule,
      ],
    }).compile();
    const app = moduleRef.createNestApplication();
    await app.init();
    close = () => app.close();
    prisma = app.get(PrismaService);
    const db = prisma.db();
    if (!db) {
      throw new Error('prisma client missing');
    }
    repo = new PrismaSupportTicketRepository(db);
  });

  afterAll(async () => {
    await close();
  });

  const input = (userId: string | null, contact: string | null) => ({
    channel: (userId ? 'APP' : 'WEB') as 'APP' | 'WEB',
    requesterUserId: userId,
    requesterRole: 'CUSTOMER',
    contact,
    category: 'OTHER' as const,
    subject: 'Kiểm tra giới hạn',
    description: 'Mười yêu cầu gửi cùng lúc.',
  });

  function outcome(results: PromiseSettledResult<unknown>[]) {
    const ok = results.filter((r) => r.status === 'fulfilled').length;
    const limited = results.filter(
      (r) => r.status === 'rejected' && r.reason instanceof SupportRuleError,
    ).length;
    return { ok, limited };
  }

  it('grants exactly maxOpen tickets to one user under 10 concurrent submits', async () => {
    const user = await prisma.db()!.user.create({ data: { displayName: 'support-pg' } });
    const now = new Date();
    const results = await Promise.allSettled(
      Array.from({ length: 10 }, () =>
        repo.create(input(user.id, null), { kind: 'user', userId: user.id, maxOpen: 5 }, now),
      ),
    );
    expect(outcome(results)).toEqual({ ok: 5, limited: 5 });
  });

  it('grants exactly the daily cap to one contact under 8 concurrent submits', async () => {
    const contact = `pg-${randomUUID()}@dealgo.test`;
    const now = new Date();
    const since = new Date(now.getTime() - 86_400_000);
    const results = await Promise.allSettled(
      Array.from({ length: 8 }, () =>
        repo.create(input(null, contact), { kind: 'contact', contact, maxPerWindow: 3, since }, now),
      ),
    );
    expect(outcome(results)).toEqual({ ok: 3, limited: 5 });
    const codes = await prisma.db()!.supportTicket.findMany({ where: { contact }, select: { code: true } });
    expect(new Set(codes.map((c) => c.code)).size).toBe(3);
  });

  it('replies, reopens and audits through the Prisma repository', async () => {
    const db = prisma.db()!;
    const user = await db.user.create({ data: { displayName: 'support-pg-flow' } });
    const staff = await db.user.create({ data: { displayName: 'support-pg-staff' } });
    const now = new Date();
    const ticket = await repo.create(input(user.id, null), { kind: 'user', userId: user.id, maxOpen: 50 }, now);
    const audit = { actorUserId: staff.id, reason: 'pg', metadata: { op: 'test' } };
    const { ticket: replied } = await repo.addStaffReply(ticket.id, staff.id, 'Đã nhận', new Date(), audit);
    expect(replied).toMatchObject({ status: 'IN_PROGRESS', lastAuthor: 'STAFF' });
    const resolved = await repo.updateByStaff(ticket.id, { status: 'RESOLVED' }, new Date(), audit);
    expect(resolved.resolvedAt).toBeInstanceOf(Date);
    const reopened = await repo.addRequesterMessage(ticket.id, user.id, 'Chưa xong', new Date());
    expect(reopened).toMatchObject({ status: 'IN_PROGRESS', resolvedAt: null });
    expect(reopened.messages.map((m) => m.authorType)).toEqual(['REQUESTER', 'STAFF', 'REQUESTER']);
    await expect(repo.addRequesterMessage(ticket.id, staff.id, 'x', new Date())).rejects.toBeInstanceOf(
      SupportRuleError,
    );
    const found = await repo.listForOps({ page: 1, limit: 5, q: ticket.code.toLowerCase() });
    expect(found.items.map((t) => t.id)).toEqual([ticket.id]);
    expect(found.items[0]?.lastMessagePreview).toBe('Chưa xong');
    const mine = await repo.listForUser(user.id, { page: 1, limit: 5 });
    expect(mine).toMatchObject({ total: 1, activeCount: 1, doneCount: 0 });
    const audits = await db.opsAuditLog.count({ where: { entityType: 'SUPPORT_TICKET', entityId: ticket.id } });
    expect(audits).toBe(2);
  });
});
