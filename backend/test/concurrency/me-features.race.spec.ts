/**
 * Postgres race checks for the address book (per-user row lock).
 * Skips when DATABASE_URL is unset (default unit suite uses memory repos).
 */
import { ConfigModule } from '@nestjs/config';
import { Test } from '@nestjs/testing';
import { loadEnv } from '../../src/platform/config/env.js';
import { PrismaModule } from '../../src/platform/database/prisma.module.js';
import { PrismaService } from '../../src/platform/database/prisma.service.js';
import { PrismaAddressBookRepository } from '../../src/modules/address-book/address-book-prisma.repository.js';
import { PrismaRatingRepository } from '../../src/modules/rating/rating-prisma.repository.js';
import { randomUUID } from 'node:crypto';

const hasDatabase = Boolean(process.env.DATABASE_URL?.trim());
const describePg = hasDatabase ? describe : describe.skip;

describePg('address book race (postgres)', () => {
  let prisma: PrismaService;
  let repo: PrismaAddressBookRepository;
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
    repo = new PrismaAddressBookRepository(prisma.db()!);
  });

  afterAll(async () => {
    await close();
  });

  async function newUser() {
    return prisma.db()!.user.create({
      data: { displayName: 'Race', phone: `+8490${String(Date.now()).slice(-7)}${Math.floor(Math.random() * 10)}` },
    });
  }

  it('keeps one default and one HOME under concurrent writes', async () => {
    const user = await newUser();
    const results = await Promise.allSettled([
      ...Array.from({ length: 6 }, (_, i) =>
        repo.create(user.id, { kind: 'OTHER', label: `P${i}`, addressLine: `${i} Lê Lợi`, isDefault: true }),
      ),
      ...Array.from({ length: 3 }, (_, i) =>
        repo.create(user.id, { kind: 'HOME', label: `Nhà ${i}`, addressLine: `${i} Hùng Vương` }),
      ),
    ]);
    const rows = await repo.list(user.id);
    expect(rows.filter((r) => r.isDefault)).toHaveLength(1);
    expect(rows.filter((r) => r.kind === 'HOME')).toHaveLength(1);
    expect(results.filter((r) => r.status === 'rejected')).toHaveLength(2);
    await prisma.db()!.user.delete({ where: { id: user.id } });
  });

  it('accepts exactly one of two racing ratings for the same order', async () => {
    const user = await newUser();
    const ratings = new PrismaRatingRepository(prisma.db()!);
    const subjectId = randomUUID();
    const rate = (stars: number) =>
      ratings.create({
        subjectType: 'FOOD_ORDER',
        subjectId,
        raterId: user.id,
        driverId: null,
        storeId: null,
        driverStars: null,
        storeStars: stars,
        tags: ['TASTY_FOOD'],
        comment: null,
      });
    const results = await Promise.allSettled([rate(5), rate(1)]);
    expect(results.filter((r) => r.status === 'fulfilled')).toHaveLength(1);
    const rejected = results.find((r) => r.status === 'rejected') as PromiseRejectedResult;
    expect(rejected.reason).toMatchObject({ name: 'RatingAlreadySubmittedError' });
    expect((await ratings.find('FOOD_ORDER', subjectId))?.tags).toEqual(['TASTY_FOOD']);
    await prisma.db()!.user.delete({ where: { id: user.id } });
  });
});
