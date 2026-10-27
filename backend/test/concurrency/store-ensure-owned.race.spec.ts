/**
 * Merchant home + menu opened together created two stores for one owner.
 * Skips when DATABASE_URL is unset.
 */
import { ConfigModule } from '@nestjs/config';
import { Test } from '@nestjs/testing';
import { loadEnv } from '../../src/platform/config/env.js';
import { PrismaModule } from '../../src/platform/database/prisma.module.js';
import { PrismaService } from '../../src/platform/database/prisma.service.js';
import { PrismaFoodRepository } from '../../src/modules/food-order/food-prisma.repository.js';

const hasDatabase = Boolean(process.env.DATABASE_URL?.trim());
const describePg = hasDatabase ? describe : describe.skip;

describePg('ensureOwnedStore race (postgres)', () => {
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

  it('concurrent first opens create exactly one store per owner', async () => {
    const db = prisma.db()!;
    const repo = new PrismaFoodRepository(db as never);
    const owner = await db.user.create({ data: { displayName: 'Race Store Owner' } });
    const results = await Promise.all(
      Array.from({ length: 6 }, () => repo.ensureOwnedStore(owner.id, 'Race Store')),
    );
    const count = await db.foodStore.count({ where: { ownerId: owner.id } });
    expect(count).toBe(1);
    expect(new Set(results.map((r) => r.id)).size).toBe(1);
    await db.foodStore.deleteMany({ where: { ownerId: owner.id } });
    await db.user.delete({ where: { id: owner.id } });
  });
});
