/**
 * DEC-PROD-036 — super-admin resets another operator's password: hash replaced, OPS sessions
 * revoked, audit row written (without the hash) in one transaction. Skips without DATABASE_URL.
 */
import { randomUUID } from 'node:crypto';
import { ConfigModule } from '@nestjs/config';
import { Test } from '@nestjs/testing';
import { loadEnv } from '../../src/platform/config/env.js';
import { PrismaModule } from '../../src/platform/database/prisma.module.js';
import { PrismaService } from '../../src/platform/database/prisma.service.js';
import { PrismaIdentityRepository } from '../../src/modules/identity/identity-prisma.repository.js';

const hasDatabase = Boolean(process.env.DATABASE_URL?.trim());
const describePg = hasDatabase ? describe : describe.skip;

describePg('ops password reset (postgres)', () => {
  let prisma: PrismaService;
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
    prisma = app.get(PrismaService);
    close = () => app.close();
  });

  afterAll(async () => {
    await close();
  });

  it('replaces the hash, revokes OPS sessions only, and audits', async () => {
    const db = prisma.db()!;
    const repo = new PrismaIdentityRepository(db as never);
    const tag = randomUUID().slice(0, 8);
    const root = await repo.createUser({ email: `root-${tag}@dealgo.test`, phone: null, displayName: 'Root' });
    const staff = await repo.createUser({ email: `staff-${tag}@dealgo.test`, phone: null, displayName: 'Staff' });
    await repo.saveOpsCredential(root.id, 'root-hash');
    await repo.setOpsSuperAdmin(root.id, true);
    await repo.saveOpsCredential(staff.id, 'old-hash');
    const future = new Date(Date.now() + 3_600_000);
    const opsSession = await db.session.create({
      data: { userId: staff.id, familyId: randomUUID(), channel: 'OPS', refreshTokenHash: `ops-${tag}`, expiresAt: future },
    });
    const appSession = await db.session.create({
      data: { userId: staff.id, familyId: randomUUID(), channel: 'CUSTOMER', refreshTokenHash: `app-${tag}`, expiresAt: future },
    });

    expect(await repo.findOpsCredential(root.id)).toEqual({
      passwordHash: 'root-hash',
      superAdmin: true,
      staffRole: 'ADMIN',
    });
    await repo.resetOpsPassword({
      targetUserId: staff.id,
      passwordHash: 'new-hash',
      actorUserId: root.id,
      reason: 'forgot password',
      at: new Date(),
    });

    expect(await repo.findOpsCredential(staff.id)).toEqual({
      passwordHash: 'new-hash',
      superAdmin: false,
      staffRole: 'ADMIN',
    });
    const sessions = await db.session.findMany({ where: { id: { in: [opsSession.id, appSession.id] } } });
    expect(sessions.find((s) => s.id === opsSession.id)?.revokedAt).not.toBeNull();
    expect(sessions.find((s) => s.id === appSession.id)?.revokedAt).toBeNull();
    const audits = await db.opsAuditLog.findMany({ where: { entityId: staff.id } });
    expect(audits).toHaveLength(1);
    expect(audits[0]).toMatchObject({
      actorUserId: root.id,
      action: 'OPS_PASSWORD_RESET',
      entityType: 'OPS_STAFF',
      reason: 'forgot password',
    });
    expect(JSON.stringify(audits[0].metadata)).not.toContain('hash');

    const noLogin = await repo.createUser({ email: `nologin-${tag}@dealgo.test`, phone: null, displayName: 'X' });
    await expect(
      repo.resetOpsPassword({
        targetUserId: noLogin.id,
        passwordHash: 'h',
        actorUserId: root.id,
        reason: 'nope',
        at: new Date(),
      }),
    ).rejects.toThrow('OPS_NO_PASSWORD_LOGIN');
    expect(await db.opsAuditLog.count({ where: { entityId: noLogin.id } })).toBe(0);
  });
});
