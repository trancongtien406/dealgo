/**
 * Concurrent approve vs reject of one KYC application against Postgres: exactly one review
 * wins (conditional update on SUBMITTED). Skips when DATABASE_URL is unset.
 */
import { randomUUID } from 'node:crypto';
import { ConfigModule } from '@nestjs/config';
import { Test } from '@nestjs/testing';
import { loadEnv } from '../../src/platform/config/env.js';
import { PrismaModule } from '../../src/platform/database/prisma.module.js';
import { PrismaService } from '../../src/platform/database/prisma.service.js';
import { PrismaPartnerRepository } from '../../src/modules/partner/partner-prisma.repository.js';

const hasDatabase = Boolean(process.env.DATABASE_URL?.trim());
const describePg = hasDatabase ? describe : describe.skip;

describePg('partner application review race (postgres)', () => {
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

  it('lets exactly one of approve / reject / approve win', async () => {
    const db = prisma.db()!;
    const repo = new PrismaPartnerRepository(db);
    const user = await db.user.create({
      data: { displayName: 'Race Applicant', phone: `+8490${Date.now().toString().slice(-7)}` },
    });
    const reviewer = await db.user.create({ data: { displayName: 'Race Ops' } });
    const app = await repo.upsertSubmit({
      id: randomUUID(),
      userId: user.id,
      role: 'DRIVER',
      metadata: {},
      documents: [],
      now: new Date(),
    });

    const results = await Promise.all([
      repo.review({ id: app.id, status: 'APPROVED', reason: null, reviewIssues: [], reviewedBy: reviewer.id, now: new Date() }),
      repo.review({
        id: app.id,
        status: 'REJECTED',
        reason: 'blurry',
        reviewIssues: [{ section: 'ID_CARD', note: 'blurry' }],
        reviewedBy: reviewer.id,
        now: new Date(),
      }),
      repo.review({ id: app.id, status: 'APPROVED', reason: null, reviewIssues: [], reviewedBy: reviewer.id, now: new Date() }),
    ]);
    const winners = results.filter((row) => row !== null);
    expect(winners).toHaveLength(1);
    const stored = await repo.findById(app.id);
    expect(stored?.status).toBe(winners[0]!.status);
    if (stored?.status === 'REJECTED') {
      expect(stored.reviewIssues).toEqual([{ section: 'ID_CARD', note: 'blurry' }]);
    } else {
      expect(stored?.reviewIssues).toEqual([]);
    }
  });
});
