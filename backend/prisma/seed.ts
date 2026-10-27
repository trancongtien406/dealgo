/**
 * Repeatable local/demo seed for Admin (ADMIN_UI_MOCK=0).
 *
 * Usage:
 *   npm run seed
 *
 * Reads DATABASE_URL and OPS_BOOTSTRAP_* from env / backend/.env.
 * Safe to re-run: upserts by email/phone/idempotencyKey/(userId, role).
 */
import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { argon2id, hash as argon2Hash } from 'argon2';
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '../src/generated/prisma/client.js';
import { OPS_FAQ_SEEDS } from '../src/modules/support/ops-faq.seed.js';
import { INITIAL_PROMOTION_SEED } from '../src/modules/promotion/promotion.seed.js';
import { PLATFORM_SETTING_SEED_DEFAULTS } from '../src/platform/settings/platform-settings.seed.js';
import { assertSeedAllowed, resolveSeedPassword } from './seed-guard.js';

import {
  specForKey,
  type PlatformSettingKey,
} from '../src/platform/settings/platform-settings.catalog.js';

const LOCAL_DATABASE_URL =
  'postgresql://dealgo:dealgo_dev@127.0.0.1:5433/dealgo?schema=public';

/** Resolved in main() after .env is loaded (DEC-PROD-053: no hardcoded fallback). */
export let DEFAULT_SEED_PASSWORD = '';

const passwordHashCache = new Map<string, Promise<string>>();

function getPasswordHash(password: string): Promise<string> {
  let existing = passwordHashCache.get(password);
  if (!existing) {
    existing = argon2Hash(password, { type: argon2id });
    passwordHashCache.set(password, existing);
  }
  return existing;
}

// Landmarks for realistic map pins and routing
const HCM = {
  bitexco: { lat: 10.7719, lng: 106.7042 },
  benThanh: { lat: 10.7725, lng: 106.698 },
  nguyenHue: { lat: 10.7743, lng: 106.7019 },
  district1: { lat: 10.7769, lng: 106.7009 },
  thaoDien: { lat: 10.8021, lng: 106.734 },
  phuNhuan: { lat: 10.7994, lng: 106.6802 },
  binhThanh: { lat: 10.8105, lng: 106.7091 },
} as const;

const DNG = {
  dragonBridge: { lat: 16.0611, lng: 108.2272 },
  myKhe: { lat: 16.0597, lng: 108.2435 },
  sonTra: { lat: 16.0828, lng: 108.2443 },
  airport: { lat: 16.0538, lng: 108.2022 },
  nguHanhSon: { lat: 16.0022, lng: 108.2638 },
  hanMarket: { lat: 16.0682, lng: 108.2241 },
} as const;

type SeedCounts = {
  opsUsers: number;
  customers: number;
  drivers: number;
  merchants: number;
  stores: number;
  menuItems: number;
  rides: number;
  rideOffers: number;
  foodOrders: number;
  partnerApplications: number;
  ledgerAccounts: number;
  ledgerJournals: number;
  platformSettings: number;
  authMethodPolicies: number;
  opsFaqs: number;
  promotions: number;
};

function loadDotEnv(): void {
  const envFile = resolve(process.cwd(), '.env');
  if (!existsSync(envFile)) {
    return;
  }
  for (const raw of readFileSync(envFile, 'utf8').split('\n')) {
    const line = raw.trim();
    if (!line || line.startsWith('#')) {
      continue;
    }
    const eq = line.indexOf('=');
    if (eq <= 0) {
      continue;
    }
    const key = line.slice(0, eq).trim();
    if (process.env[key] !== undefined) {
      continue;
    }
    let value = line.slice(eq + 1).trim();
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }
    process.env[key] = value;
  }
}

function databaseUrl(): string {
  return process.env.DATABASE_URL?.trim() || LOCAL_DATABASE_URL;
}

function normalizeEmail(email: string): string {
  return email.trim().toLowerCase();
}

async function upsertUser(
  db: PrismaClient,
  input: {
    email: string | null;
    phone: string | null;
    displayName: string;
    phoneVerified?: boolean;
    emailVerified?: boolean;
    password?: string | null;
    /** App email login uses customer_credentials; Admin uses ops_credentials. */
    passwordTarget?: 'customer' | 'ops';
  },
): Promise<{ id: string; created: boolean }> {
  const email = input.email ? normalizeEmail(input.email) : null;
  let existing = email
    ? await db.user.findUnique({ where: { email } })
    : null;
  if (!existing && input.phone) {
    existing = await db.user.findUnique({ where: { phone: input.phone } });
  }

  const now = new Date();
  let userId: string;
  let created = false;

  if (existing) {
    userId = existing.id;
    await db.user.update({
      where: { id: existing.id },
      data: {
        displayName: input.displayName,
        email: email ?? existing.email,
        phone: input.phone ?? existing.phone,
        phoneVerifiedAt: input.phoneVerified
          ? (existing.phoneVerifiedAt ?? now)
          : existing.phoneVerifiedAt,
        emailVerifiedAt: input.emailVerified
          ? (existing.emailVerifiedAt ?? now)
          : existing.emailVerifiedAt,
      },
    });
  } else {
    const createdUser = await db.user.create({
      data: {
        email,
        phone: input.phone,
        displayName: input.displayName,
        phoneVerifiedAt: input.phoneVerified ? now : null,
        emailVerifiedAt: input.emailVerified ? now : null,
      },
    });
    userId = createdUser.id;
    created = true;
  }

  const password =
    input.password === undefined ? DEFAULT_SEED_PASSWORD : input.password;
  if (password) {
    const passwordHash = await getPasswordHash(password);
    if (input.passwordTarget === 'ops') {
      await db.opsCredential.upsert({
        where: { userId },
        create: { userId, passwordHash },
        update: { passwordHash },
      });
    } else {
      await db.customerCredential.upsert({
        where: { userId },
        create: { userId, passwordHash },
        update: { passwordHash },
      });
    }
  }

  return { id: userId, created };
}

async function ensureGrant(
  db: PrismaClient,
  userId: string,
  role: 'CUSTOMER' | 'DRIVER' | 'MERCHANT' | 'OPS',
  status: 'ACTIVE' | 'PENDING' | 'SUSPENDED' = 'ACTIVE',
): Promise<void> {
  await db.roleGrant.upsert({
    where: { userId_role: { userId, role } },
    create: { userId, role, status },
    update: { status },
  });
}

async function ensureOpsOperator(db: PrismaClient): Promise<string> {
  const email = normalizeEmail(
    process.env.OPS_BOOTSTRAP_EMAIL?.trim() || 'ops@localhost',
  );
  const password =
    process.env.OPS_BOOTSTRAP_PASSWORD?.trim() || DEFAULT_SEED_PASSWORD;
  const { id } = await upsertUser(db, {
    email,
    phone: null,
    displayName: 'DealGo Ops Admin',
    emailVerified: true,
    password,
    passwordTarget: 'ops',
  });
  await ensureGrant(db, id, 'OPS', 'ACTIVE');
  // DEC-PROD-036: the bootstrap operator is the super-admin (resets other ops passwords).
  await db.opsCredential.update({ where: { userId: id }, data: { superAdmin: true } });
  return id;
}

/** DEC-PROD-033 demo: size + topping on a milk tea; only created when the dish has none. */
const DEMO_ITEM_OPTIONS: Record<
  string,
  Array<{ name: string; minSelect: number; maxSelect: number; options: Array<{ name: string; priceDeltaVnd: number }> }>
> = {
  'Trà sữa Phúc Long truyền thống': [
    {
      name: 'Size',
      minSelect: 1,
      maxSelect: 1,
      options: [
        { name: 'M', priceDeltaVnd: 0 },
        { name: 'L', priceDeltaVnd: 10_000 },
      ],
    },
    {
      name: 'Topping',
      minSelect: 0,
      maxSelect: 2,
      options: [
        { name: 'Trân châu', priceDeltaVnd: 8_000 },
        { name: 'Thạch đào', priceDeltaVnd: 8_000 },
        { name: 'Kem cheese', priceDeltaVnd: 12_000 },
      ],
    },
  ],
};

async function ensureDemoItemOptions(db: PrismaClient, storeId: string): Promise<void> {
  for (const [itemName, groups] of Object.entries(DEMO_ITEM_OPTIONS)) {
    const item = await db.foodItem.findFirst({ where: { storeId, name: itemName } });
    if (!item) continue;
    if ((await db.foodOptionGroup.count({ where: { itemId: item.id } })) > 0) continue;
    for (const [position, group] of groups.entries()) {
      await db.foodOptionGroup.create({
        data: {
          itemId: item.id,
          name: group.name,
          minSelect: group.minSelect,
          maxSelect: group.maxSelect,
          position,
          options: {
            create: group.options.map((option, index) => ({ ...option, position: index })),
          },
        },
      });
    }
  }
}

async function ensureStoreWithMenu(
  db: PrismaClient,
  ownerId: string,
  name: string,
  lat: number,
  lng: number,
  category: string,
  items: ReadonlyArray<{ name: string; priceVnd: number }>,
  addressLabel: string | null = null,
): Promise<{ storeId: string; itemIds: string[]; menuItemsCreated: number }> {
  const existing = await db.foodStore.findFirst({
    where: { ownerId, name },
    include: { items: true },
  });

  let storeId: string;
  if (existing) {
    storeId = existing.id;
    await db.foodStore.update({
      where: { id: storeId },
      data: { lat, lng, category, addressLabel },
    });
  } else {
    const created = await db.foodStore.create({
      data: { ownerId, name, lat, lng, category, addressLabel },
    });
    storeId = created.id;
  }

  let menuItemsCreated = 0;
  const itemIds: string[] = [];
  for (const item of items) {
    const found = await db.foodItem.findFirst({
      where: { storeId, name: item.name },
    });
    if (found) {
      await db.foodItem.update({
        where: { id: found.id },
        data: { priceVnd: item.priceVnd, available: true },
      });
      itemIds.push(found.id);
    } else {
      const created = await db.foodItem.create({
        data: {
          storeId,
          name: item.name,
          priceVnd: item.priceVnd,
          available: true,
        },
      });
      itemIds.push(created.id);
      menuItemsCreated += 1;
    }
  }

  return { storeId, itemIds, menuItemsCreated };
}

async function upsertRide(
  db: PrismaClient,
  input: {
    customerId: string;
    idempotencyKey: string;
    status:
      | 'NEGOTIATING'
      | 'ASSIGNED'
      | 'DRIVER_EN_ROUTE'
      | 'DRIVER_ARRIVED'
      | 'IN_TRIP'
      | 'COMPLETED'
      | 'CANCELLED'
      | 'EXPIRED';
    pickup: { lat: number; lng: number; label: string };
    dropoff: { lat: number; lng: number; label: string };
    offeredFareVnd: number;
    referenceFareVnd: number;
    agreedFareVnd: number | null;
    assignedDriverId: string | null;
    expiresAt: Date;
    updatedAt?: Date;
  },
): Promise<string> {
  const existing = await db.ride.findUnique({
    where: {
      customerId_idempotencyKey: {
        customerId: input.customerId,
        idempotencyKey: input.idempotencyKey,
      },
    },
  });

  if (existing) {
    await db.ride.update({
      where: { id: existing.id },
      data: {
        status: input.status,
        // DEC-PROD-035: seed cancellations are the customer's.
        cancelledBy: input.status === 'CANCELLED' ? 'CUSTOMER' : null,
        pickupLat: input.pickup.lat,
        pickupLng: input.pickup.lng,
        pickupLabel: input.pickup.label,
        dropoffLat: input.dropoff.lat,
        dropoffLng: input.dropoff.lng,
        dropoffLabel: input.dropoff.label,
        offeredFareVnd: input.offeredFareVnd,
        referenceFareVnd: input.referenceFareVnd,
        agreedFareVnd: input.agreedFareVnd,
        assignedDriverId: input.assignedDriverId,
        selectedOfferId: null,
        expiresAt: input.expiresAt,
        ...(input.updatedAt ? { updatedAt: input.updatedAt } : {}),
      },
    });
    await db.rideOffer.deleteMany({ where: { rideId: existing.id } });
    return existing.id;
  }

  const created = await db.ride.create({
    data: {
      vehicleClassCode: 'MOTORBIKE',
      customerId: input.customerId,
      idempotencyKey: input.idempotencyKey,
      status: input.status,
      // DEC-PROD-035: seed cancellations are the customer's.
      cancelledBy: input.status === 'CANCELLED' ? 'CUSTOMER' : null,
      pickupLat: input.pickup.lat,
      pickupLng: input.pickup.lng,
      pickupLabel: input.pickup.label,
      dropoffLat: input.dropoff.lat,
      dropoffLng: input.dropoff.lng,
      dropoffLabel: input.dropoff.label,
      offeredFareVnd: input.offeredFareVnd,
      referenceFareVnd: input.referenceFareVnd,
      agreedFareVnd: input.agreedFareVnd,
      assignedDriverId: input.assignedDriverId,
      expiresAt: input.expiresAt,
      ...(input.updatedAt ? { updatedAt: input.updatedAt } : {}),
    },
  });
  return created.id;
}

async function createOffer(
  db: PrismaClient,
  input: {
    rideId: string;
    driverId: string;
    amountVnd: number;
    kind: 'ACCEPT' | 'COUNTER';
    status: 'PENDING' | 'SELECTED' | 'LOST';
    expiresAt: Date;
  },
): Promise<string> {
  const offer = await db.rideOffer.create({
    data: {
      rideId: input.rideId,
      driverId: input.driverId,
      amountVnd: input.amountVnd,
      kind: input.kind,
      status: input.status,
      expiresAt: input.expiresAt,
    },
  });
  return offer.id;
}

async function upsertFoodOrder(
  db: PrismaClient,
  input: {
    customerId: string;
    storeId: string;
    idempotencyKey: string;
    status:
      | 'PLACED'
      | 'PREPARING'
      | 'READY'
      | 'ASSIGNED'
      | 'PICKED_UP'
      | 'DELIVERED'
      | 'FAILED'
      | 'CANCELLED';
    deliveryFareVnd: number;
    dropoff: { lat: number; lng: number; label: string };
    assignedDriverId: string | null;
    lines: ReadonlyArray<{
      itemId: string;
      name: string;
      unitPriceVnd: number;
      quantity: number;
    }>;
    updatedAt?: Date;
  },
): Promise<string> {
  const subtotalVnd = input.lines.reduce(
    (sum, line) => sum + line.unitPriceVnd * line.quantity,
    0,
  );
  const totalVnd = subtotalVnd + input.deliveryFareVnd;
  // DEC-PROD-034: same pickup snapshot the app writes at placement.
  const store = await db.foodStore.findUnique({
    where: { id: input.storeId },
    select: { lat: true, lng: true, addressLabel: true },
  });
  const hasPoint = store?.lat != null && store?.lng != null;
  const pickup = {
    pickupLat: hasPoint ? store!.lat : null,
    pickupLng: hasPoint ? store!.lng : null,
    pickupLabel: hasPoint ? (store!.addressLabel?.slice(0, 200) ?? null) : null,
  };

  const existing = await db.foodOrder.findUnique({
    where: {
      customerId_idempotencyKey: {
        customerId: input.customerId,
        idempotencyKey: input.idempotencyKey,
      },
    },
  });

  if (existing) {
    await db.foodOrderLine.deleteMany({ where: { orderId: existing.id } });
    await db.foodOrder.update({
      where: { id: existing.id },
      data: {
        storeId: input.storeId,
        status: input.status,
        // DEC-PROD-035: seed cancellations are the customer's.
        cancelledBy: input.status === 'CANCELLED' ? 'CUSTOMER' : null,
        deliveryFareVnd: input.deliveryFareVnd,
        subtotalVnd,
        totalVnd,
        dropoffLat: input.dropoff.lat,
        dropoffLng: input.dropoff.lng,
        dropoffLabel: input.dropoff.label,
        ...pickup,
        assignedDriverId: input.assignedDriverId,
        ...(input.updatedAt ? { updatedAt: input.updatedAt } : {}),
        lines: {
          create: input.lines.map((line) => ({
            itemId: line.itemId,
            name: line.name,
            unitPriceVnd: line.unitPriceVnd,
            quantity: line.quantity,
          })),
        },
      },
    });
    return existing.id;
  }

  const created = await db.foodOrder.create({
    data: {
      customerId: input.customerId,
      storeId: input.storeId,
      idempotencyKey: input.idempotencyKey,
      status: input.status,
      // DEC-PROD-035: seed cancellations are the customer's.
      cancelledBy: input.status === 'CANCELLED' ? 'CUSTOMER' : null,
      deliveryFareVnd: input.deliveryFareVnd,
      subtotalVnd,
      totalVnd,
      dropoffLat: input.dropoff.lat,
      dropoffLng: input.dropoff.lng,
      dropoffLabel: input.dropoff.label,
      ...pickup,
      assignedDriverId: input.assignedDriverId,
      ...(input.updatedAt ? { updatedAt: input.updatedAt } : {}),
      lines: {
        create: input.lines.map((line) => ({
          itemId: line.itemId,
          name: line.name,
          unitPriceVnd: line.unitPriceVnd,
          quantity: line.quantity,
        })),
      },
    },
  });
  return created.id;
}

async function upsertPartnerApplication(
  db: PrismaClient,
  input: {
    userId: string;
    role: 'DRIVER' | 'MERCHANT';
    status: 'DRAFT' | 'SUBMITTED' | 'APPROVED' | 'REJECTED';
    metadata: Record<string, unknown>;
    reason?: string | null;
    reviewedBy?: string | null;
  },
): Promise<void> {
  const submittedAt =
    input.status !== 'DRAFT' ? new Date(Date.now() - 2 * 3600_000) : null;
  const reviewedAt =
    input.status === 'APPROVED' || input.status === 'REJECTED'
      ? new Date(Date.now() - 3600_000)
      : null;

  await db.partnerApplication.upsert({
    where: { userId_role: { userId: input.userId, role: input.role } },
    create: {
      userId: input.userId,
      role: input.role,
      status: input.status,
      metadata: input.metadata as any,
      // Seed rows carry document metadata only (no stored bytes): Admin shows them as
      // "không có tệp". Real uploads go through POST /v1/me/partner-applications.
      documents: seedDocumentRefs(input.userId, input.role),
      submittedAt,
      reviewedAt,
      reviewedBy: input.reviewedBy ?? null,
      reason: input.reason ?? null,
    },
    update: {
      status: input.status,
      metadata: input.metadata as any,
      submittedAt,
      reviewedAt,
      reviewedBy: input.reviewedBy ?? null,
      reason: input.reason ?? null,
    },
  });
}

async function ensureLedgerAccounts(
  db: PrismaClient,
): Promise<{ cashAccount: string; obligationAccount: string }> {
  const cash = await db.ledgerAccount.upsert({
    where: { code: 'sandbox.cod.cash_in_transit' },
    create: {
      code: 'sandbox.cod.cash_in_transit',
      name: 'Tiền mặt đang chuyển (COD)',
      kind: 'ASSET',
    },
    update: {
      name: 'Tiền mặt đang chuyển (COD)',
      kind: 'ASSET',
    },
  });

  const obligation = await db.ledgerAccount.upsert({
    where: { code: 'sandbox.cod.obligation' },
    create: {
      code: 'sandbox.cod.obligation',
      name: 'Nghĩa vụ COD đối soát',
      kind: 'LIABILITY',
    },
    update: {
      name: 'Nghĩa vụ COD đối soát',
      kind: 'LIABILITY',
    },
  });

  return { cashAccount: cash.id, obligationAccount: obligation.id };
}

async function ensureCodJournal(
  db: PrismaClient,
  input: {
    entityType: 'RIDE' | 'FOOD_ORDER';
    entityId: string;
    amountVnd: number;
    cashAccountId: string;
    obligationAccountId: string;
    postedAt?: Date;
  },
): Promise<boolean> {
  const existing = await db.ledgerJournal.findUnique({
    where: {
      entityType_entityId_event: {
        entityType: input.entityType,
        entityId: input.entityId,
        event: 'COD_OBLIGATION_POSTED',
      },
    },
  });
  if (existing) {
    return false;
  }

  await db.ledgerJournal.create({
    data: {
      entityType: input.entityType,
      entityId: input.entityId,
      event: 'COD_OBLIGATION_POSTED',
      status: 'POSTED',
      currency: 'VND',
      amountVnd: input.amountVnd,
      postedAt: input.postedAt ?? new Date(),
      entries: {
        create: [
          {
            accountId: input.cashAccountId,
            direction: 'DEBIT',
            amountVnd: input.amountVnd,
          },
          {
            accountId: input.obligationAccountId,
            direction: 'CREDIT',
            amountVnd: input.amountVnd,
          },
        ],
      },
    },
  });
  return true;
}

async function ensureAuthPolicies(db: PrismaClient): Promise<number> {
  const methods = ['PASSKEY', 'PHONE_SMS', 'EMAIL_LOGIN_IDENTIFIER'] as const;
  let count = 0;
  for (const method of methods) {
    await db.authMethodPolicy.upsert({
      where: { method },
      create: { method, enabled: true },
      update: {},
    });
    count += 1;
  }
  return count;
}

async function ensurePlatformSettings(db: PrismaClient): Promise<number> {
  const settings: Array<{ key: string; value: string; valueType: 'string' | 'number' | 'json' }> = [
    { key: 'DRIVER_SEARCH_RADIUS_KM', value: '5', valueType: 'number' },
    { key: 'RIDE_OFFER_TTL_SECONDS', value: '30', valueType: 'number' },
    { key: 'RIDE_MIN_FARE_VND', value: '15000', valueType: 'number' },
    { key: 'RIDE_MAX_FARE_VND', value: '1000000', valueType: 'number' },
    { key: 'RIDE_REFERENCE_VND_PER_KM', value: '12000', valueType: 'number' },
    { key: 'FOOD_MIN_DELIVERY_VND', value: '15000', valueType: 'number' },
    { key: 'FOOD_MAX_DELIVERY_VND', value: '100000', valueType: 'number' },
    { key: 'CONTACT_WINDOW_MINUTES', value: '60', valueType: 'number' },
    { key: 'MAX_CONCURRENT_JOBS_PER_DRIVER', value: '1', valueType: 'number' },
    {
      key: 'PAYMENT_METHODS_ENABLED',
      value: '["COD","SANDBOX"]',
      valueType: 'json',
    },
    // Rating window + platform fees: shared with the migration and the settings service.
    ...Object.entries(PLATFORM_SETTING_SEED_DEFAULTS).map(([key, value]) => ({
      key,
      value: value ?? '',
      valueType: specForKey(key as PlatformSettingKey).valueType,
    })),
  ];

  for (const s of settings) {
    await db.platformSetting.upsert({
      where: { key: s.key },
      create: {
        key: s.key,
        value: s.value,
        valueType: s.valueType,
      },
      update: {},
    });
  }
  return settings.length;
}

async function ensureFaqs(db: PrismaClient): Promise<number> {
  let created = 0;
  for (const seed of OPS_FAQ_SEEDS) {
    const existing = await db.opsFaqEntry.findFirst({
      where: { openId: seed.openId },
    });
    if (!existing) {
      await db.opsFaqEntry.create({
        data: {
          openId: seed.openId,
          question: seed.question,
          suggestedAnswer: seed.suggestedAnswer,
          status: 'DRAFT',
          category: seed.category,
          sortOrder: seed.sortOrder,
        },
      });
      created += 1;
    }
  }
  return created;
}

async function ensurePromotions(db: PrismaClient): Promise<number> {
  let created = 0;
  for (const seed of INITIAL_PROMOTION_SEED) {
    const existing = await db.promotion.findUnique({ where: { code: seed.code } });
    if (existing) {
      continue;
    }
    const { id: _sampleId, ...campaign } = seed;
    await db.promotion.create({
      data: {
        ...campaign,
        maxDiscountAmount: campaign.maxDiscountAmount ?? null,
        startDate: new Date(campaign.startDate),
        endDate: new Date(campaign.endDate),
        createdAt: new Date(campaign.createdAt),
        updatedAt: new Date(campaign.updatedAt),
      },
    });
    created += 1;
  }
  return created;
}

async function ensureChatThread(
  db: PrismaClient,
  input: {
    rideId?: string;
    foodOrderId?: string;
    messages: Array<{ senderUserId: string; body: string }>;
  },
): Promise<void> {
  let thread = input.rideId
    ? await db.chatThread.findUnique({ where: { rideId: input.rideId } })
    : input.foodOrderId
      ? await db.chatThread.findUnique({
          where: { foodOrderId: input.foodOrderId },
        })
      : null;

  if (!thread) {
    thread = await db.chatThread.create({
      data: {
        rideId: input.rideId,
        foodOrderId: input.foodOrderId,
      },
    });
  }

  for (const msg of input.messages) {
    const existing = await db.chatMessage.findFirst({
      where: {
        threadId: thread.id,
        senderUserId: msg.senderUserId,
        body: msg.body,
      },
    });
    if (!existing) {
      await db.chatMessage.create({
        data: {
          threadId: thread.id,
          senderUserId: msg.senderUserId,
          body: msg.body,
        },
      });
    }
  }
}

async function main(): Promise<void> {
  loadDotEnv();
  assertSeedAllowed(process.env);
  DEFAULT_SEED_PASSWORD = resolveSeedPassword(process.env);
  const url = databaseUrl();
  const adapter = new PrismaPg(
    { connectionString: url, max: 4 },
    { onPoolError: () => undefined },
  );
  const db = new PrismaClient({ adapter });

  const counts: SeedCounts = {
    opsUsers: 0,
    customers: 0,
    drivers: 0,
    merchants: 0,
    stores: 0,
    menuItems: 0,
    rides: 0,
    rideOffers: 0,
    foodOrders: 0,
    partnerApplications: 0,
    ledgerAccounts: 0,
    ledgerJournals: 0,
    platformSettings: 0,
    authMethodPolicies: 0,
    opsFaqs: 0,
    promotions: 0,
  };

  try {
    await db.$queryRaw`SELECT 1`;

    // 1. Ops operator and staff directory
    const opsId = await ensureOpsOperator(db);
    counts.opsUsers = 1;

    const opsStaffList = [
      {
        email: 'minh@dealgo.vn',
        phone: '+84908000001',
        displayName: 'Trần Quang Minh (Quản trị)',
        password: DEFAULT_SEED_PASSWORD,
        status: 'ACTIVE' as const,
      },
      {
        email: 'support.hoa@seed.dealgo.local',
        phone: '+84908000002',
        displayName: 'Nguyễn Thu Hòa (CSKH)',
        password: DEFAULT_SEED_PASSWORD,
        status: 'ACTIVE' as const,
      },
      {
        email: 'finance.nam@seed.dealgo.local',
        phone: '+84908000003',
        displayName: 'Lê Hoàng Nam (Tài chính)',
        password: DEFAULT_SEED_PASSWORD,
        status: 'ACTIVE' as const,
      },
      {
        email: 'ops.hcm@seed.dealgo.local',
        phone: '+84908000004',
        displayName: 'Võ Quốc Huy (Vận hành HCM)',
        password: DEFAULT_SEED_PASSWORD,
        status: 'ACTIVE' as const,
      },
      {
        email: 'ops.pending@seed.dealgo.local',
        phone: '+84908000005',
        displayName: 'Đỗ Văn Khang (Đang mời)',
        password: DEFAULT_SEED_PASSWORD,
        status: 'PENDING' as const,
      },
      {
        email: 'ops.suspended@seed.dealgo.local',
        phone: '+84908000006',
        displayName: 'Hoàng Thị Tuyết (Tạm đình chỉ)',
        password: DEFAULT_SEED_PASSWORD,
        status: 'SUSPENDED' as const,
      },
    ];

    for (const staff of opsStaffList) {
      const { id } = await upsertUser(db, {
        email: staff.email,
        phone: staff.phone,
        displayName: staff.displayName,
        emailVerified: true,
        phoneVerified: true,
        password: staff.password,
        passwordTarget: 'ops',
      });
      await ensureGrant(db, id, 'OPS', staff.status);
      counts.opsUsers += 1;
    }

    // 2. Customers
    const customers = [
      {
        phone: '+84902000001',
        email: 'customer.an@seed.dealgo.local',
        displayName: 'Nguyễn Văn An',
        password: DEFAULT_SEED_PASSWORD,
      },
      {
        phone: '+84902000002',
        email: 'customer.binh@seed.dealgo.local',
        displayName: 'Trần Thị Bình',
        password: DEFAULT_SEED_PASSWORD,
      },
      {
        phone: '+84902000003',
        email: 'customer.chi@seed.dealgo.local',
        displayName: 'Lê Minh Chi',
        password: DEFAULT_SEED_PASSWORD,
      },
      {
        phone: '+84902000004',
        email: 'customer.duy@seed.dealgo.local',
        displayName: 'Vũ Quốc Duy',
        password: DEFAULT_SEED_PASSWORD,
      },
      {
        phone: '+84902000005',
        email: 'customer.hoa@seed.dealgo.local',
        displayName: 'Đặng Mai Hoa',
        password: DEFAULT_SEED_PASSWORD,
      },
      {
        phone: '+84902000006',
        email: 'customer.khoa@seed.dealgo.local',
        displayName: 'Bùi Anh Khoa',
        password: DEFAULT_SEED_PASSWORD,
      },
      {
        phone: '+84902000007',
        email: 'customer.lan@seed.dealgo.local',
        displayName: 'Phan Tuyết Lan',
        password: DEFAULT_SEED_PASSWORD,
      },
    ] as const;

    const customerIds: string[] = [];
    for (const customer of customers) {
      const { id } = await upsertUser(db, {
        ...customer,
        phoneVerified: true,
        emailVerified: true,
      });
      await ensureGrant(db, id, 'CUSTOMER');
      customerIds.push(id);
      counts.customers += 1;
    }

    // 3. Drivers (HCM & Da Nang)
    const drivers = [
      {
        phone: '+84903000001',
        email: 'driver.dung@seed.dealgo.local',
        displayName: 'Phạm Văn Dũng',
        password: DEFAULT_SEED_PASSWORD,
        online: true,
        lat: HCM.benThanh.lat,
        lng: HCM.benThanh.lng,
      },
      {
        phone: '+84903000002',
        email: 'driver.em@seed.dealgo.local',
        displayName: 'Hoàng Thị Em',
        password: DEFAULT_SEED_PASSWORD,
        online: true,
        lat: DNG.dragonBridge.lat,
        lng: DNG.dragonBridge.lng,
      },
      {
        phone: '+84903000003',
        email: 'driver.phong@seed.dealgo.local',
        displayName: 'Võ Quốc Phong',
        password: DEFAULT_SEED_PASSWORD,
        online: true,
        lat: DNG.myKhe.lat,
        lng: DNG.myKhe.lng,
      },
      {
        phone: '+84903000004',
        email: 'driver.hai@seed.dealgo.local',
        displayName: 'Nguyễn Văn Hải',
        password: DEFAULT_SEED_PASSWORD,
        online: true,
        lat: HCM.nguyenHue.lat,
        lng: HCM.nguyenHue.lng,
      },
      {
        phone: '+84903000005',
        email: 'driver.mai@seed.dealgo.local',
        displayName: 'Lê Thị Mai',
        password: DEFAULT_SEED_PASSWORD,
        online: false,
        lat: HCM.phuNhuan.lat,
        lng: HCM.phuNhuan.lng,
      },
      {
        phone: '+84903000006',
        email: 'driver.tam@seed.dealgo.local',
        displayName: 'Trần Văn Tám',
        password: DEFAULT_SEED_PASSWORD,
        online: false,
        lat: DNG.sonTra.lat,
        lng: DNG.sonTra.lng,
      },
    ] as const;

    const driverIds: string[] = [];
    for (const driver of drivers) {
      const { id } = await upsertUser(db, {
        phone: driver.phone,
        email: driver.email,
        displayName: driver.displayName,
        password: driver.password,
        phoneVerified: true,
        emailVerified: true,
      });
      await ensureGrant(db, id, 'DRIVER');
      await db.driverPresence.upsert({
        where: { userId: id },
        create: {
          userId: id,
          online: driver.online,
          lat: driver.lat,
          lng: driver.lng,
        },
        update: {
          online: driver.online,
          lat: driver.lat,
          lng: driver.lng,
        },
      });
      driverIds.push(id);
      counts.drivers += 1;
    }

    // 4. Merchants & Stores
    const merchants = [
      {
        phone: '+84901110001',
        email: 'merchant.bunbo@seed.dealgo.local',
        displayName: 'Bún Bò Huế Gia Truyền',
        password: DEFAULT_SEED_PASSWORD,
        storeName: 'Bún Bò Huế — Nguyễn Huệ',
        addressLabel: 'Đường Nguyễn Huệ, Quận 1, TP.HCM',
        category: 'pho',
        lat: HCM.nguyenHue.lat,
        lng: HCM.nguyenHue.lng,
        items: [
          { name: 'Bún bò đặc biệt', priceVnd: 60_000 },
          { name: 'Trà tắc mát lạnh', priceVnd: 25_000 },
          { name: 'Chả cua hấp', priceVnd: 35_000 },
        ],
      },
      {
        phone: '+84904000001',
        email: 'merchant.coffee@seed.dealgo.local',
        displayName: 'Cà Phê Sài Gòn',
        password: DEFAULT_SEED_PASSWORD,
        storeName: 'Cà Phê Sài Gòn — Bitexco',
        addressLabel: 'Tòa Bitexco, Hải Triều, Quận 1, TP.HCM',
        category: 'cafe',
        lat: HCM.bitexco.lat,
        lng: HCM.bitexco.lng,
        items: [
          { name: 'Cà phê sữa đá', priceVnd: 35_000 },
          { name: 'Bạc xỉu ba tầng', priceVnd: 40_000 },
          { name: 'Bánh mì ốp la xúc xích', priceVnd: 45_000 },
        ],
      },
      {
        phone: '+84905110001',
        email: 'merchant.comtam@seed.dealgo.local',
        displayName: 'Cơm Tấm Ba Ghiền',
        password: DEFAULT_SEED_PASSWORD,
        storeName: 'Cơm Tấm Ba Ghiền — Quận 1',
        addressLabel: 'Quận 1, TP.HCM',
        category: 'rice',
        lat: HCM.district1.lat,
        lng: HCM.district1.lng,
        items: [
          { name: 'Cơm sườn bì chả đặc biệt', priceVnd: 65_000 },
          { name: 'Cơm sườn ốp la', priceVnd: 55_000 },
          { name: 'Canh rong biển thịt bằm', priceVnd: 20_000 },
          { name: 'Trà đá giải nhiệt', priceVnd: 5_000 },
        ],
      },
      {
        phone: '+84906110001',
        email: 'merchant.phuclong@seed.dealgo.local',
        displayName: 'Trà Sữa Phúc Long',
        password: DEFAULT_SEED_PASSWORD,
        storeName: 'Trà Sữa Phúc Long — Thảo Điền',
        addressLabel: 'Thảo Điền, TP. Thủ Đức, TP.HCM',
        category: 'cafe',
        lat: HCM.thaoDien.lat,
        lng: HCM.thaoDien.lng,
        items: [
          { name: 'Trà sữa Phúc Long truyền thống', priceVnd: 50_000 },
          { name: 'Trà đào đá xay', priceVnd: 60_000 },
          { name: 'Trà lài sen vàng', priceVnd: 55_000 },
          { name: 'Bánh sừng bò nướng', priceVnd: 35_000 },
        ],
      },
      {
        phone: '+84907110001',
        email: 'merchant.miquang@seed.dealgo.local',
        displayName: 'Mì Quảng Bà Mua',
        password: DEFAULT_SEED_PASSWORD,
        storeName: 'Mì Quảng Bà Mua — Hải Châu Đà Nẵng',
        addressLabel: 'Quận Hải Châu, Đà Nẵng',
        category: 'noodles',
        lat: DNG.hanMarket.lat,
        lng: DNG.hanMarket.lng,
        items: [
          { name: 'Mì Quảng gà ta', priceVnd: 50_000 },
          { name: 'Mì Quảng tôm thịt', priceVnd: 55_000 },
          { name: 'Mì Quảng ếch đồng', priceVnd: 60_000 },
          { name: 'Nước mía sầu riêng', priceVnd: 20_000 },
        ],
      },
    ] as const;

    const storeIds: string[] = [];
    const storeMenus: Array<{
      storeId: string;
      itemIds: string[];
      items: (typeof merchants)[number]['items'];
    }> = [];

    for (const merchant of merchants) {
      const { id } = await upsertUser(db, {
        phone: merchant.phone,
        email: merchant.email,
        displayName: merchant.displayName,
        password: merchant.password,
        phoneVerified: true,
        emailVerified: true,
      });
      await ensureGrant(db, id, 'MERCHANT');
      counts.merchants += 1;

      const store = await ensureStoreWithMenu(
        db,
        id,
        merchant.storeName,
        merchant.lat,
        merchant.lng,
        merchant.category,
        merchant.items,
        merchant.addressLabel,
      );
      storeIds.push(store.storeId);
      await ensureDemoItemOptions(db, store.storeId);
      storeMenus.push({
        storeId: store.storeId,
        itemIds: store.itemIds,
        items: merchant.items,
      });
      counts.stores += 1;
      counts.menuItems += store.itemIds.length;
    }

    // 5. Ledger accounts
    const ledger = await ensureLedgerAccounts(db);
    counts.ledgerAccounts = 2;

    const offerExpiry = new Date(Date.now() + 30 * 60_000);
    const rideExpiry = new Date(Date.now() + 20 * 60_000);

    // 6. Rides across all lifecycle statuses
    // 6.1 NEGOTIATING — Customer 0 in Da Nang
    const negotiatingRideId = await upsertRide(db, {
      customerId: customerIds[0]!,
      idempotencyKey: 'seed:ride:negotiating',
      status: 'NEGOTIATING',
      pickup: { ...DNG.hanMarket, label: 'Chợ Hàn, Hải Châu' },
      dropoff: { ...DNG.myKhe, label: 'Bãi biển Mỹ Khê' },
      offeredFareVnd: 45_000,
      referenceFareVnd: 50_000,
      agreedFareVnd: null,
      assignedDriverId: null,
      expiresAt: rideExpiry,
    });
    counts.rides += 1;

    await createOffer(db, {
      rideId: negotiatingRideId,
      driverId: driverIds[1]!,
      amountVnd: 45_000,
      kind: 'ACCEPT',
      status: 'PENDING',
      expiresAt: offerExpiry,
    });
    await createOffer(db, {
      rideId: negotiatingRideId,
      driverId: driverIds[2]!,
      amountVnd: 48_000,
      kind: 'COUNTER',
      status: 'PENDING',
      expiresAt: offerExpiry,
    });
    counts.rideOffers += 2;

    // 6.2 ASSIGNED — Customer 1 in Da Nang
    const assignedRideId = await upsertRide(db, {
      customerId: customerIds[1]!,
      idempotencyKey: 'seed:ride:assigned',
      status: 'ASSIGNED',
      pickup: { ...DNG.dragonBridge, label: 'Cầu Rồng' },
      dropoff: { ...DNG.airport, label: 'Sân bay Quốc tế Đà Nẵng' },
      offeredFareVnd: 35_000,
      referenceFareVnd: 38_000,
      agreedFareVnd: 35_000,
      assignedDriverId: driverIds[1]!,
      expiresAt: offerExpiry,
    });
    counts.rides += 1;
    const assignedOfferId = await createOffer(db, {
      rideId: assignedRideId,
      driverId: driverIds[1]!,
      amountVnd: 35_000,
      kind: 'ACCEPT',
      status: 'SELECTED',
      expiresAt: offerExpiry,
    });
    await db.ride.update({
      where: { id: assignedRideId },
      data: { selectedOfferId: assignedOfferId },
    });
    counts.rideOffers += 1;

    // Chat on assigned ride
    await ensureChatThread(db, {
      rideId: assignedRideId,
      messages: [
        {
          senderUserId: customerIds[1]!,
          body: 'Em đang đứng ở đuôi Cầu Rồng hướng Bạch Đằng anh nhé.',
        },
        {
          senderUserId: driverIds[1]!,
          body: 'Dạ vâng anh, em đang quay đầu xe, 2 phút nữa em tới.',
        },
      ],
    });

    // 6.3 DRIVER_EN_ROUTE — Customer 2 in Da Nang
    const enRouteRideId = await upsertRide(db, {
      customerId: customerIds[2]!,
      idempotencyKey: 'seed:ride:en_route',
      status: 'DRIVER_EN_ROUTE',
      pickup: { ...DNG.sonTra, label: 'Bán đảo Sơn Trà' },
      dropoff: { ...DNG.dragonBridge, label: 'Cầu Rồng' },
      offeredFareVnd: 55_000,
      referenceFareVnd: 60_000,
      agreedFareVnd: 55_000,
      assignedDriverId: driverIds[2]!,
      expiresAt: offerExpiry,
    });
    counts.rides += 1;
    const enRouteOfferId = await createOffer(db, {
      rideId: enRouteRideId,
      driverId: driverIds[2]!,
      amountVnd: 55_000,
      kind: 'ACCEPT',
      status: 'SELECTED',
      expiresAt: offerExpiry,
    });
    await db.ride.update({
      where: { id: enRouteRideId },
      data: { selectedOfferId: enRouteOfferId },
    });
    counts.rideOffers += 1;

    // 6.4 IN_TRIP — Customer 3 in HCM
    const inTripRideId = await upsertRide(db, {
      customerId: customerIds[3]!,
      idempotencyKey: 'seed:ride:in_trip',
      status: 'IN_TRIP',
      pickup: { ...HCM.benThanh, label: 'Chợ Bến Thành' },
      dropoff: { ...HCM.bitexco, label: 'Tháp Tài chính Bitexco' },
      offeredFareVnd: 28_000,
      referenceFareVnd: 30_000,
      agreedFareVnd: 28_000,
      assignedDriverId: driverIds[0]!,
      expiresAt: offerExpiry,
    });
    counts.rides += 1;
    const inTripOfferId = await createOffer(db, {
      rideId: inTripRideId,
      driverId: driverIds[0]!,
      amountVnd: 28_000,
      kind: 'ACCEPT',
      status: 'SELECTED',
      expiresAt: offerExpiry,
    });
    await db.ride.update({
      where: { id: inTripRideId },
      data: { selectedOfferId: inTripOfferId },
    });
    counts.rideOffers += 1;

    // 6.5 COMPLETED — Customer 4 in HCM
    const completedRideId = await upsertRide(db, {
      customerId: customerIds[4]!,
      idempotencyKey: 'seed:ride:completed',
      status: 'COMPLETED',
      pickup: { ...HCM.nguyenHue, label: 'Phố đi bộ Nguyễn Huệ' },
      dropoff: { ...HCM.thaoDien, label: 'Thảo Điền, TP. Thủ Đức' },
      offeredFareVnd: 75_000,
      referenceFareVnd: 80_000,
      agreedFareVnd: 75_000,
      assignedDriverId: driverIds[3]!,
      expiresAt: new Date(Date.now() - 60_000),
      updatedAt: new Date(Date.now() - 30_000),
    });
    counts.rides += 1;
    const completedOfferId = await createOffer(db, {
      rideId: completedRideId,
      driverId: driverIds[3]!,
      amountVnd: 75_000,
      kind: 'ACCEPT',
      status: 'SELECTED',
      expiresAt: new Date(Date.now() - 30_000),
    });
    await db.ride.update({
      where: { id: completedRideId },
      data: { selectedOfferId: completedOfferId },
    });
    counts.rideOffers += 1;

    // Post COD journal for completed ride
    const j1 = await ensureCodJournal(db, {
      entityType: 'RIDE',
      entityId: completedRideId,
      amountVnd: 75_000,
      cashAccountId: ledger.cashAccount,
      obligationAccountId: ledger.obligationAccount,
      postedAt: new Date(Date.now() - 30_000),
    });
    if (j1) counts.ledgerJournals += 1;

    // 6.6 CANCELLED — Customer 5 in HCM
    await upsertRide(db, {
      customerId: customerIds[5]!,
      idempotencyKey: 'seed:ride:cancelled',
      status: 'CANCELLED',
      pickup: { ...HCM.phuNhuan, label: 'Quận Phú Nhuận' },
      dropoff: { ...HCM.benThanh, label: 'Chợ Bến Thành' },
      offeredFareVnd: 42_000,
      referenceFareVnd: 45_000,
      agreedFareVnd: null,
      assignedDriverId: null,
      expiresAt: new Date(Date.now() - 120_000),
      updatedAt: new Date(Date.now() - 60_000),
    });
    counts.rides += 1;

    // 6.7 EXPIRED — Customer 6 in HCM
    await upsertRide(db, {
      customerId: customerIds[6]!,
      idempotencyKey: 'seed:ride:expired',
      status: 'EXPIRED',
      pickup: { ...HCM.thaoDien, label: 'Khu dân cư Thảo Điền' },
      dropoff: { ...HCM.district1, label: 'Trung tâm Quận 1' },
      offeredFareVnd: 50_000,
      referenceFareVnd: 60_000,
      agreedFareVnd: null,
      assignedDriverId: null,
      expiresAt: new Date(Date.now() - 3600_000),
      updatedAt: new Date(Date.now() - 3600_000),
    });
    counts.rides += 1;

    // 7. Food Orders across all lifecycle statuses
    const menu0 = storeMenus[0]!;
    const menu1 = storeMenus[1]!;
    const menu2 = storeMenus[2]!;
    const menu3 = storeMenus[3]!;
    const menu4 = storeMenus[4]!;

    // 7.1 PLACED — Customer 0
    await upsertFoodOrder(db, {
      customerId: customerIds[0]!,
      storeId: menu0.storeId,
      idempotencyKey: 'seed:food:placed',
      status: 'PLACED',
      deliveryFareVnd: 25_000,
      dropoff: { ...HCM.district1, label: 'Tòa nhà Landmark, Quận 1' },
      assignedDriverId: null,
      lines: [
        {
          itemId: menu0.itemIds[0]!,
          name: menu0.items[0]!.name,
          unitPriceVnd: menu0.items[0]!.priceVnd,
          quantity: 2,
        },
        {
          itemId: menu0.itemIds[1]!,
          name: menu0.items[1]!.name,
          unitPriceVnd: menu0.items[1]!.priceVnd,
          quantity: 1,
        },
      ],
    });
    counts.foodOrders += 1;

    // 7.2 PREPARING — Customer 1
    await upsertFoodOrder(db, {
      customerId: customerIds[1]!,
      storeId: menu1.storeId,
      idempotencyKey: 'seed:food:preparing',
      status: 'PREPARING',
      deliveryFareVnd: 20_000,
      dropoff: { ...HCM.thaoDien, label: 'Căn hộ Masteri Thảo Điền' },
      assignedDriverId: null,
      lines: [
        {
          itemId: menu1.itemIds[0]!,
          name: menu1.items[0]!.name,
          unitPriceVnd: menu1.items[0]!.priceVnd,
          quantity: 2,
        },
        {
          itemId: menu1.itemIds[1]!,
          name: menu1.items[1]!.name,
          unitPriceVnd: menu1.items[1]!.priceVnd,
          quantity: 1,
        },
      ],
    });
    counts.foodOrders += 1;

    // 7.3 READY — Customer 2 (Food cooked, ready for driver pickup!)
    await upsertFoodOrder(db, {
      customerId: customerIds[2]!,
      storeId: menu2.storeId,
      idempotencyKey: 'seed:food:ready',
      status: 'READY',
      deliveryFareVnd: 18_000,
      dropoff: { ...HCM.phuNhuan, label: 'Chung cư Phú Nhuận Plaza' },
      assignedDriverId: null,
      lines: [
        {
          itemId: menu2.itemIds[0]!,
          name: menu2.items[0]!.name,
          unitPriceVnd: menu2.items[0]!.priceVnd,
          quantity: 1,
        },
        {
          itemId: menu2.itemIds[2]!,
          name: menu2.items[2]!.name,
          unitPriceVnd: menu2.items[2]!.priceVnd,
          quantity: 1,
        },
      ],
    });
    counts.foodOrders += 1;

    // 7.4 ASSIGNED — Customer 3
    const assignedFoodOrderId = await upsertFoodOrder(db, {
      customerId: customerIds[3]!,
      storeId: menu3.storeId,
      idempotencyKey: 'seed:food:assigned',
      status: 'ASSIGNED',
      deliveryFareVnd: 22_000,
      dropoff: { ...HCM.binhThanh, label: 'Khu Vinhomes Central Park' },
      assignedDriverId: driverIds[0]!,
      lines: [
        {
          itemId: menu3.itemIds[0]!,
          name: menu3.items[0]!.name,
          unitPriceVnd: menu3.items[0]!.priceVnd,
          quantity: 2,
        },
      ],
    });
    counts.foodOrders += 1;

    // Chat on assigned food order
    await ensureChatThread(db, {
      foodOrderId: assignedFoodOrderId,
      messages: [
        {
          senderUserId: customerIds[3]!,
          body: 'Anh lấy giúp em thêm ít đá riêng nhé, em cảm ơn.',
        },
        {
          senderUserId: driverIds[0]!,
          body: 'Dạ vâng anh, quán đang cho vào túi, em lấy đá riêng rồi đi ngay ạ.',
        },
      ],
    });

    // 7.5 PICKED_UP — Customer 4 in Da Nang
    await upsertFoodOrder(db, {
      customerId: customerIds[4]!,
      storeId: menu4.storeId,
      idempotencyKey: 'seed:food:picked_up',
      status: 'PICKED_UP',
      deliveryFareVnd: 20_000,
      dropoff: { ...DNG.myKhe, label: 'Khách sạn Mường Thanh Mỹ Khê' },
      assignedDriverId: driverIds[2]!,
      lines: [
        {
          itemId: menu4.itemIds[0]!,
          name: menu4.items[0]!.name,
          unitPriceVnd: menu4.items[0]!.priceVnd,
          quantity: 2,
        },
        {
          itemId: menu4.itemIds[3]!,
          name: menu4.items[3]!.name,
          unitPriceVnd: menu4.items[3]!.priceVnd,
          quantity: 2,
        },
      ],
    });
    counts.foodOrders += 1;

    // 7.6 DELIVERED — Customer 5
    const deliveredFoodOrderId = await upsertFoodOrder(db, {
      customerId: customerIds[5]!,
      storeId: menu0.storeId,
      idempotencyKey: 'seed:food:delivered',
      status: 'DELIVERED',
      deliveryFareVnd: 25_000,
      dropoff: { ...HCM.district1, label: 'Tòa nhà Sunwah, Quận 1' },
      assignedDriverId: driverIds[3]!,
      lines: [
        {
          itemId: menu0.itemIds[0]!,
          name: menu0.items[0]!.name,
          unitPriceVnd: menu0.items[0]!.priceVnd,
          quantity: 1,
        },
      ],
      updatedAt: new Date(Date.now() - 15 * 60_000),
    });
    counts.foodOrders += 1;

    // Post COD journal for delivered food order
    const j2 = await ensureCodJournal(db, {
      entityType: 'FOOD_ORDER',
      entityId: deliveredFoodOrderId,
      amountVnd: 85_000,
      cashAccountId: ledger.cashAccount,
      obligationAccountId: ledger.obligationAccount,
      postedAt: new Date(Date.now() - 15 * 60_000),
    });
    if (j2) counts.ledgerJournals += 1;

    // 7.7 CANCELLED — Customer 6
    await upsertFoodOrder(db, {
      customerId: customerIds[6]!,
      storeId: menu1.storeId,
      idempotencyKey: 'seed:food:cancelled',
      status: 'CANCELLED',
      deliveryFareVnd: 20_000,
      dropoff: { ...HCM.thaoDien, label: 'Khu biệt thự Thảo Điền' },
      assignedDriverId: null,
      lines: [
        {
          itemId: menu1.itemIds[0]!,
          name: menu1.items[0]!.name,
          unitPriceVnd: menu1.items[0]!.priceVnd,
          quantity: 1,
        },
      ],
      updatedAt: new Date(Date.now() - 30 * 60_000),
    });
    counts.foodOrders += 1;

    // 8. Partner Applications (KYC/KYB)
    const applicants = [
      {
        phone: '+84905000001',
        email: 'applicant.driver1@seed.dealgo.local',
        displayName: 'Trần Đại Nghĩa',
        role: 'DRIVER' as const,
        status: 'SUBMITTED' as const,
        metadata: {
          vehicleType: 'Honda AirBlade 125cc',
          plateNumber: '43-E1 892.45',
          city: 'Đà Nẵng',
        },
      },
      {
        phone: '+84905000002',
        email: 'applicant.merchant1@seed.dealgo.local',
        displayName: 'Nguyễn Thị Tuyết Mai',
        role: 'MERCHANT' as const,
        status: 'SUBMITTED' as const,
        metadata: {
          storeName: 'Tiệm Bánh Mì Phượng Đà Nẵng',
          address: '42 Trần Phú, Hải Châu',
          city: 'Đà Nẵng',
        },
      },
      {
        phone: '+84905000003',
        email: 'applicant.driver2@seed.dealgo.local',
        displayName: 'Lê Thanh Tùng',
        role: 'DRIVER' as const,
        status: 'APPROVED' as const,
        reviewedBy: opsId,
        metadata: {
          vehicleType: 'Yamaha Grande 125cc',
          plateNumber: '59-B1 789.12',
          city: 'TP. Hồ Chí Minh',
        },
      },
      {
        phone: '+84905000004',
        email: 'applicant.driver3@seed.dealgo.local',
        displayName: 'Ngô Quốc Bảo',
        role: 'DRIVER' as const,
        status: 'REJECTED' as const,
        reviewedBy: opsId,
        reason:
          'Ảnh chụp giấy phép lái xe bị mờ, không nhìn rõ ngày hết hạn. Vui lòng chụp lại.',
        metadata: {
          vehicleType: 'Honda Wave RSX 110cc',
          plateNumber: '59-C2 345.67',
          city: 'TP. Hồ Chí Minh',
        },
      },
    ] as const;

    for (const applicant of applicants) {
      const { id } = await upsertUser(db, {
        phone: applicant.phone,
        email: applicant.email,
        displayName: applicant.displayName,
        phoneVerified: true,
      });
      await ensureGrant(db, id, 'CUSTOMER');
      await upsertPartnerApplication(db, {
        userId: id,
        role: applicant.role,
        status: applicant.status,
        metadata: applicant.metadata,
        reason: 'reason' in applicant ? applicant.reason : null,
        reviewedBy: 'reviewedBy' in applicant ? applicant.reviewedBy : null,
      });
      counts.partnerApplications += 1;
    }

    // Drop ops password rows on app-only users left by older seed builds that
    // wrote every password into ops_credentials instead of customer_credentials.
    await db.opsCredential.deleteMany({
      where: {
        user: { roleGrants: { none: { role: 'OPS' } } },
      },
    });

    // 9. Auth method policies
    counts.authMethodPolicies = await ensureAuthPolicies(db);

    // 10. Platform settings
    counts.platformSettings = await ensurePlatformSettings(db);

    // 11. Ops FAQs
    counts.opsFaqs = await ensureFaqs(db);

    // 12. Promotion campaigns (sample data; never seeded by the API at runtime)
    counts.promotions = await ensurePromotions(db);

    console.log(
      JSON.stringify(
        {
          ok: true,
          counts,
          opsEmail: normalizeEmail(
            process.env.OPS_BOOTSTRAP_EMAIL?.trim() || 'ops@localhost',
          ),
          defaultPassword: DEFAULT_SEED_PASSWORD,
          staffAccounts: [
            { email: 'ops@localhost', role: 'ADMIN', password: DEFAULT_SEED_PASSWORD },
            { email: 'minh@dealgo.vn', role: 'ADMIN', password: DEFAULT_SEED_PASSWORD },
            { email: 'support.hoa@seed.dealgo.local', role: 'SUPPORT', password: DEFAULT_SEED_PASSWORD },
            { email: 'finance.nam@seed.dealgo.local', role: 'FINANCE', password: DEFAULT_SEED_PASSWORD },
            { email: 'ops.hcm@seed.dealgo.local', role: 'OPS', password: DEFAULT_SEED_PASSWORD },
          ],
        },
        null,
        2,
      ),
    );
  } finally {
    await db.$disconnect();
  }
}

main().catch((error: unknown) => {
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
});

function seedDocumentRefs(userId: string, role: 'DRIVER' | 'MERCHANT') {
  const kinds =
    role === 'DRIVER'
      ? (['ID_FRONT', 'ID_BACK', 'SELFIE', 'LICENSE', 'VEHICLE_REG'] as const)
      : (['BUSINESS_LICENSE', 'REP_ID_FRONT', 'REP_ID_BACK'] as const);
  const uploadedAt = new Date(Date.now() - 2 * 3600_000).toISOString();
  return kinds.map((kind) => ({
    key: `mock://seed/${userId}/${role}/${kind.toLowerCase()}.jpg`,
    kind,
    label: kind,
    contentType: 'image/jpeg',
    sizeBytes: 0,
    uploadedAt,
  }));
}
