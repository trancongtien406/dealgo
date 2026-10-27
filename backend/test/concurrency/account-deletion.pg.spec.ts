/**
 * DEC-PROD-037 — S027 account deletion on Postgres: real blocker queries (rides, food orders,
 * store orders, unsettled platform fees, staff), the confirm transaction (soft-delete, sessions,
 * push tokens, presence, store pause), the purge (PII gone, history kept) and fee settlement.
 * Also the audited super-admin flag change. Skips without DATABASE_URL.
 */
import { randomUUID } from 'node:crypto';
import { ConfigModule } from '@nestjs/config';
import { Test } from '@nestjs/testing';
import { loadEnv } from '../../src/platform/config/env.js';
import { PrismaModule } from '../../src/platform/database/prisma.module.js';
import { PrismaService } from '../../src/platform/database/prisma.service.js';
import { PrismaFoodRepository } from '../../src/modules/food-order/food-prisma.repository.js';
import { PrismaIdentityRepository } from '../../src/modules/identity/identity-prisma.repository.js';
import { PrismaAccountDeletionRepository } from '../../src/modules/account-deletion/account-deletion-prisma.repository.js';
import { DELETED_USER_DISPLAY_NAME } from '../../src/modules/account-deletion/account-deletion.repository.js';

const hasDatabase = Boolean(process.env.DATABASE_URL?.trim());
const describePg = hasDatabase ? describe : describe.skip;
const DAY = 24 * 60 * 60 * 1000;

describePg('account deletion (postgres)', () => {
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

  const ride = (customerId: string, status: 'NEGOTIATING' | 'ASSIGNED' | 'COMPLETED', driverId: string | null, tag: string) =>
    prisma.db()!.ride.create({
      data: {
        vehicleClassCode: 'MOTORBIKE',
        id: randomUUID(),
        customerId,
        pickupLat: 16.05,
        pickupLng: 108.2,
        pickupLabel: 'A',
        dropoffLat: 16.06,
        dropoffLng: 108.21,
        dropoffLabel: 'B',
        offeredFareVnd: 30_000,
        referenceFareVnd: 30_000,
        status,
        assignedDriverId: driverId,
        expiresAt: new Date(Date.now() + 600_000),
        idempotencyKey: `idem-del-${status}-${tag}-${randomUUID().slice(0, 4)}`,
      },
    });

  it('computes blockers from live rides, orders, store orders, fees and staff grants', async () => {
    const db = prisma.db()!;
    const repo = new PrismaAccountDeletionRepository(db as never);
    const food = new PrismaFoodRepository(db as never);
    const tag = randomUUID().slice(0, 8);
    const customer = await db.user.create({ data: { displayName: 'Del Customer' } });
    const driver = await db.user.create({ data: { displayName: 'Del Driver' } });
    const owner = await db.user.create({ data: { displayName: 'Del Owner' } });
    const staff = await db.user.create({ data: { displayName: 'Del Staff' } });
    const ops = await db.user.create({ data: { displayName: 'Del Ops' } });
    await db.roleGrant.create({ data: { userId: staff.id, role: 'OPS', status: 'ACTIVE' } });

    const negotiating = await ride(customer.id, 'NEGOTIATING', null, tag);
    const assigned = await ride(customer.id, 'ASSIGNED', driver.id, `${tag}b`);
    await db.ride.update({ where: { id: negotiating.id }, data: { status: 'CANCELLED' } });

    const store = await db.foodStore.create({ data: { ownerId: owner.id, name: `Del ${tag}` } });
    const item = await food.createItem({ ownerId: owner.id, name: 'Bún chả', priceVnd: 35_000 });
    const order = await food.place({
      customerId: customer.id,
      storeId: store.id,
      idempotencyKey: `idem-del-food-${tag}`,
      items: [{ itemId: item.id, quantity: 1 }],
      dropoff: { lat: 16.05, lng: 108.2, label: 'Hải Châu' },
      deliveryFareVnd: 15_000,
    });

    expect(await repo.findBlockers(customer.id)).toEqual([
      { code: 'ACTIVE_RIDE', count: 1 },
      { code: 'ACTIVE_FOOD_ORDER', count: 1 },
    ]);
    expect(await repo.findBlockers(driver.id)).toEqual([{ code: 'ACTIVE_DRIVER_JOB', count: 1 }]);
    expect(await repo.findBlockers(owner.id)).toEqual([{ code: 'STORE_OPEN_ORDERS', count: 1 }]);
    expect(await repo.findBlockers(staff.id)).toEqual([{ code: 'OPS_ACCOUNT' }]);

    // Finished jobs clear the job blockers; the accrued platform fee is what remains (COD).
    await db.ride.update({ where: { id: assigned.id }, data: { status: 'COMPLETED' } });
    await db.foodOrder.update({ where: { id: order.id }, data: { status: 'DELIVERED' } });
    const completedAt = new Date(Date.now() - 60_000);
    await db.jobEarning.create({
      data: {
        entityType: 'RIDE',
        entityId: assigned.id,
        driverId: driver.id,
        fareVnd: 30_000,
        feeBps: 1000,
        feeVnd: 3_000,
        netVnd: 27_000,
        completedAt,
      },
    });
    expect(await repo.findBlockers(customer.id)).toEqual([]);
    expect(await repo.findBlockers(owner.id)).toEqual([]);
    expect(await repo.findBlockers(driver.id)).toEqual([{ code: 'UNSETTLED_COD', amountVnd: 3_000 }]);

    const settled = await repo.settleDriverFees({
      driverId: driver.id,
      actorUserId: ops.id,
      reason: 'Nộp tiền mặt',
      at: new Date(),
    });
    expect(settled?.amountVnd).toBe(3_000);
    expect(await repo.findBlockers(driver.id)).toEqual([]);
    expect(await repo.settleDriverFees({ driverId: driver.id, actorUserId: ops.id, reason: 'again', at: new Date() })).toBeNull();
    const audit = await db.opsAuditLog.findFirstOrThrow({ where: { entityId: driver.id, action: 'DRIVER_FEE_SETTLE' } });
    expect(audit).toMatchObject({ actorUserId: ops.id, entityType: 'USER', metadata: { amountVnd: 3_000 } });

    // A fee accrued after the settlement is outstanding again.
    await db.jobEarning.create({
      data: {
        entityType: 'FOOD_ORDER',
        entityId: order.id,
        driverId: driver.id,
        fareVnd: 15_000,
        feeBps: 1000,
        feeVnd: 1_500,
        netVnd: 13_500,
        completedAt: new Date(Date.now() + 1_000),
      },
    });
    expect((await repo.driverFeeBalance(driver.id)).amountVnd).toBe(1_500);
  });

  it('confirm soft-deletes atomically; purge anonymizes but keeps history', async () => {
    const db = prisma.db()!;
    const repo = new PrismaAccountDeletionRepository(db as never);
    const identity = new PrismaIdentityRepository(db as never);
    const tag = randomUUID().slice(0, 8);
    const phone = `+8497${tag.replace(/\D/g, '1').padEnd(7, '3').slice(0, 7)}`;
    const user = await db.user.create({
      data: {
        displayName: 'Nguyễn Văn Xoá',
        phone,
        email: `del-${tag}@dealgo.test`,
        phoneVerifiedAt: new Date(),
        avatarUrl: 'uploads/avatar.png',
      },
    });
    const ops = await db.user.create({ data: { displayName: 'Restore Ops' } });
    await db.roleGrant.create({ data: { userId: user.id, role: 'CUSTOMER', status: 'ACTIVE' } });
    const future = new Date(Date.now() + 3_600_000);
    await db.session.create({
      data: { userId: user.id, familyId: randomUUID(), channel: 'CUSTOMER', refreshTokenHash: `del-${tag}`, expiresAt: future },
    });
    await db.pushDeviceToken.create({ data: { userId: user.id, token: `tok-${tag}` } });
    await db.savedAddress.create({
      data: { userId: user.id, kind: 'HOME', label: 'Nhà', addressLine: '1 Lê Lợi' },
    });
    await db.partnerApplication.create({
      data: { userId: user.id, role: 'MERCHANT', status: 'APPROVED', metadata: { cccd: '0123' }, documents: [{ key: 'kyc/a.jpg' }] },
    });
    const store = await db.foodStore.create({ data: { ownerId: user.id, name: `Shop ${tag}` } });
    const history = await ride(user.id, 'COMPLETED', null, tag);

    const at = new Date();
    const request = await repo.createRequest({ userId: user.id, method: 'PHONE_OTP', codeHash: 'h', expiresAt: future });
    const result = await repo.confirm({ requestId: request.id, userId: user.id, at, purgeAfter: new Date(at.getTime() + 7 * DAY) });
    expect(result.status).toBe('scheduled');
    // Confirming twice is stale, not a second schedule.
    expect((await repo.confirm({ requestId: request.id, userId: user.id, at, purgeAfter: at })).status).toBe('stale');

    expect((await identity.findUserById(user.id))?.deletedAt).toEqual(at);
    expect(await db.session.count({ where: { userId: user.id, revokedAt: null } })).toBe(0);
    expect(await db.pushDeviceToken.count({ where: { userId: user.id } })).toBe(0);
    expect((await db.foodStore.findUniqueOrThrow({ where: { id: store.id } })).serviceMode).toBe('PAUSED');

    // Restore inside the grace period, then delete again with grace 0.
    const restored = await repo.cancelScheduled({ userId: user.id, actorUserId: ops.id, reason: 'hotline', at: new Date() });
    expect(restored?.status).toBe('CANCELLED');
    expect((await identity.findUserById(user.id))?.deletedAt).toBeNull();
    const again = await repo.createRequest({ userId: user.id, method: 'PHONE_OTP', codeHash: 'h', expiresAt: future });
    await repo.confirm({ requestId: again.id, userId: user.id, at: new Date(), purgeAfter: new Date() });

    const due = await repo.listDue(new Date(Date.now() + 1_000), 500);
    expect(due.map((r) => r.id)).toContain(again.id);
    expect(await repo.purge(again.id, new Date())).toBe(true);
    expect(await repo.purge(again.id, new Date())).toBe(false);

    const purged = await db.user.findUniqueOrThrow({ where: { id: user.id } });
    expect(purged).toMatchObject({
      displayName: DELETED_USER_DISPLAY_NAME,
      phone: null,
      email: null,
      avatarUrl: null,
      phoneVerifiedAt: null,
    });
    expect(purged.purgedAt).not.toBeNull();
    expect(await db.savedAddress.count({ where: { userId: user.id } })).toBe(0);
    expect(await db.session.count({ where: { userId: user.id } })).toBe(0);
    const app = await db.partnerApplication.findFirstOrThrow({ where: { userId: user.id } });
    expect(app.documents).toEqual([]);
    expect(app.metadata).toEqual({});
    expect((await db.roleGrant.findFirstOrThrow({ where: { userId: user.id } })).status).toBe('SUSPENDED');
    // History stays for accounting/disputes, now pointing at the anonymous row.
    expect((await db.ride.findUniqueOrThrow({ where: { id: history.id } })).customerId).toBe(user.id);
    // The phone number is free again.
    expect(await identity.findUserByPhone(phone)).toBeNull();
    expect(await repo.cancelScheduled({ userId: user.id, actorUserId: ops.id, reason: 'late', at: new Date() })).toBeNull();
    expect(await db.opsAuditLog.count({ where: { entityId: user.id, action: 'ACCOUNT_DELETION_CANCEL' } })).toBe(1);
  });

  it('changes the super-admin flag with an audit row, and refuses non-Admin credentials', async () => {
    const db = prisma.db()!;
    const identity = new PrismaIdentityRepository(db as never);
    const tag = randomUUID().slice(0, 8);
    const root = await identity.createUser({ email: `sa-root-${tag}@dealgo.test`, phone: null, displayName: 'Root' });
    const staff = await identity.createUser({ email: `sa-staff-${tag}@dealgo.test`, phone: null, displayName: 'Staff' });
    const noLogin = await identity.createUser({ email: `sa-none-${tag}@dealgo.test`, phone: null, displayName: 'None' });
    for (const u of [root, staff, noLogin]) {
      await identity.insertGrant(u.id, 'OPS', 'ACTIVE');
    }
    await identity.saveOpsCredential(root.id, 'h1');
    await identity.setOpsSuperAdmin(root.id, true);
    await identity.saveOpsCredential(staff.id, 'h2');

    const input = { actorUserId: root.id, reason: 'Phân quyền' };
    expect(await identity.changeOpsSuperAdmin({ ...input, targetUserId: noLogin.id, superAdmin: true })).toBe('no_credential');
    // Concurrent grant + duplicate grant: one change, one audit row.
    const results = await Promise.all([
      identity.changeOpsSuperAdmin({ ...input, targetUserId: staff.id, superAdmin: true }),
      identity.changeOpsSuperAdmin({ ...input, targetUserId: staff.id, superAdmin: true }),
    ]);
    expect(results.sort()).toEqual(['ok', 'unchanged']);
    // Revoking is allowed while another active super-admin (root) remains; audited too.
    expect(await identity.changeOpsSuperAdmin({ ...input, targetUserId: staff.id, superAdmin: false })).toBe('ok');
    expect((await identity.findOpsCredential(staff.id))?.superAdmin).toBe(false);
    const audits = await db.opsAuditLog.findMany({
      where: { entityId: staff.id },
      orderBy: { createdAt: 'asc' },
    });
    expect(audits.map((a) => a.action)).toEqual(['OPS_SUPER_ADMIN_GRANT', 'OPS_SUPER_ADMIN_REVOKE']);
    expect(audits[0]).toMatchObject({ entityType: 'OPS_STAFF', actorUserId: root.id, metadata: { superAdmin: true } });
  });
});
