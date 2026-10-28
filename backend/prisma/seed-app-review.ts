/**
 * App Store / Play review account (DEC-PROD-052). Idempotent: safe to re-run on any database,
 * production included (with SEED_ALLOW_PRODUCTION=true for that one run).
 *
 *  - User appreview@dealgo.trancongtien.com, email verified, CUSTOMER + DRIVER + MERCHANT active.
 *  - Approved DRIVER (MOTORBIKE) and MERCHANT applications with obviously fake demo KYC data.
 *    One DRIVER application per user, so the account drives a single vehicle class.
 *  - Store "DealGo Demo Đà Nẵng" with logo, cover, description, weekly hours (00:00–24:00 every
 *    day, so a reviewer in any time zone can order), min order, prep times, 2 menu categories and
 *    7 items (2 with a struck-through original price, 1 freshly added so it shows "Mới").
 *    Logo, cover and item images are written through the app's ObjectStorage.
 *  - 3 ACTIVE merchant-funded store vouchers (percentage with cap, fixed amount, min order).
 *  - 5 demo customers (appreview-customer-N@…, no credentials, cannot sign in), each with one
 *    DELIVERED order and a store review (stars + tags + comment); one review has a store reply.
 *    Item soldCount is raised to at least the seeded quantities (never lowered).
 *  - Platform settings APP_REVIEW_LOGIN_ENABLED=true and APP_REVIEW_EMAIL=<that email>.
 *    The fixed code itself is env APP_REVIEW_OTP_CODE on the API, never stored here.
 *
 * Password: APP_REVIEW_PASSWORD sets (or rotates) the sign-in password; it is required only
 * when the account has none yet. Everything seeded carries `seed: 'app-review'` metadata or
 * the demo names below; `npm run seed:app-review:cleanup` removes it all.
 */
import { createHash } from 'node:crypto';
import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { PrismaPg } from '@prisma/adapter-pg';
import { argon2id, hash as argon2Hash } from 'argon2';
import { PrismaClient } from '../src/generated/prisma/client.js';
import { createObjectStorage } from '../src/platform/storage/storage.module.js';
import { menuItemImagePath } from '../src/modules/catalog/menu-item-image.service.js';
import { storeLogoPath } from '../src/modules/catalog/store-logo.service.js';
import { assertSeedAllowed } from './seed-guard.js';

export const APP_REVIEW_SEED_TAG = 'app-review';
export const APP_REVIEW_DEMO_EMAIL = 'appreview@dealgo.trancongtien.com';
export const APP_REVIEW_DISPLAY_NAME = 'DealGo App Review (demo)';
export const APP_REVIEW_STORE_NAME = 'DealGo Demo Đà Nẵng';
export const APP_REVIEW_REGION_CODE = 'DN';

/** Bạch Đằng riverside, Hải Châu, Đà Nẵng. */
const STORE_PIN = { lat: 16.071, lng: 108.2246, label: 'Đường Bạch Đằng, Hải Châu 1, Hải Châu, Đà Nẵng' };

const STORE_COVER = 'food_store_cover.jpg';
const STORE_DESCRIPTION =
  'Quán demo của DealGo bên bờ sông Hàn: Mì Quảng, bún bò Huế, cơm gà và cà phê phin chuẩn vị Đà Nẵng. ' +
  'Nguyên liệu tươi mỗi sáng, đóng gói cẩn thận, giao nóng hổi quanh Hải Châu.';
const DAY_MS = 86_400_000;

const CATEGORIES = [
  { key: 'main', name: 'Món chính', position: 0 },
  { key: 'drinks', name: 'Đồ uống', position: 1 },
] as const;

// Merchant sample prices (demo store), typical for Đà Nẵng street food.
const ITEMS: readonly {
  key: string;
  category: 'main' | 'drinks';
  name: string;
  priceVnd: number;
  originalPriceVnd?: number;
  prepMinutes: number;
  image: string;
  description: string;
  /** Added "yesterday" on every run so the app's "Mới" badge stays on; the rest are 60 days old. */
  fresh?: boolean;
}[] = [
  { key: 'mi-quang', category: 'main', name: 'Mì Quảng gà', priceVnd: 45000, originalPriceVnd: 55000, prepMinutes: 12, image: 'food_mi_quang.png', description: 'Mì Quảng gà ta, bánh tráng mè, rau sống.' },
  { key: 'bun-bo', category: 'main', name: 'Bún bò Huế', priceVnd: 50000, prepMinutes: 12, image: 'food_bun_bo_hue.png', description: 'Bún bò giò heo, chả cua, sả ớt.' },
  { key: 'bun-bo-dac-biet', category: 'main', name: 'Bún bò đặc biệt', priceVnd: 65000, prepMinutes: 15, image: 'food_bun_bo_special.png', description: 'Tô lớn đủ topping: bắp bò, giò heo, chả cua, huyết.', fresh: true },
  { key: 'com-ga', category: 'main', name: 'Cơm gà xối mỡ', priceVnd: 45000, prepMinutes: 15, image: 'food_grilled_meat.png', description: 'Gà giòn, cơm chiên nhẹ, đồ chua.' },
  { key: 'banh-mi', category: 'main', name: 'Bánh mì thịt', priceVnd: 25000, prepMinutes: 5, image: 'food_banh_mi.png', description: 'Pate, chả lụa, thịt nguội, rau thơm.' },
  { key: 'ca-phe', category: 'drinks', name: 'Cà phê sữa đá', priceVnd: 20000, prepMinutes: 5, image: 'food_coffee.png', description: 'Cà phê phin pha sữa đặc.' },
  { key: 'tra-sua', category: 'drinks', name: 'Trà sữa trân châu', priceVnd: 35000, originalPriceVnd: 42000, prepMinutes: 8, image: 'food_tra_sua.png', description: 'Trà đen, sữa tươi, trân châu đường đen.' },
];
const STORE_LOGO = 'store_noodle_shop.png';

/** Store vouchers (merchant-funded, FOOD, this store only). Upserted by code; usage counters untouched. */
const OFFERS = [
  { code: 'DEMODN10', name: 'Giảm 10% cho mọi đơn', discountType: 'PERCENTAGE', discountValue: 10, maxDiscountAmount: 20000, minOrderAmount: 0, usageLimit: 200 },
  { code: 'DEMODN15K', name: 'Giảm 15.000đ cho đơn từ 60.000đ', discountType: 'FIXED_AMOUNT', discountValue: 15000, maxDiscountAmount: null, minOrderAmount: 60000, usageLimit: 100 },
  { code: 'DEMODN20', name: 'Giảm 20% cho đơn từ 150.000đ', discountType: 'PERCENTAGE', discountValue: 20, maxDiscountAmount: 40000, minOrderAmount: 150000, usageLimit: 50 },
] as const;
/** Merchant offers may run at most 180 days (STORE_OFFER_MAX_DAYS); each run renews the window. */
const OFFER_DAYS = 170;

export const APP_REVIEW_CUSTOMER_EMAIL_PREFIX = 'appreview-customer-';
export const APP_REVIEW_CUSTOMER_EMAIL_DOMAIN = '@dealgo.trancongtien.com';
const DELIVERY_FARE_VND = 15000;

/** Demo customers' delivered orders and the review each left. Tags are RatingTag values. */
const REVIEWS: readonly {
  n: number;
  name: string;
  daysAgo: number;
  lines: readonly [string, number][];
  stars: number;
  tags: string[];
  comment: string;
  reply?: string;
  dropoff: string;
}[] = [
  { n: 1, name: 'Minh Anh', daysAgo: 2, lines: [['mi-quang', 2], ['ca-phe', 1]], stars: 5, tags: ['TASTY_FOOD', 'WELL_PACKED'], comment: 'Mì Quảng đậm vị, bánh tráng giòn, đóng gói rất kỹ. Sẽ đặt lại!', reply: 'Cảm ơn Minh Anh đã ủng hộ quán! Hẹn bạn lần sau nhé.', dropoff: 'Trần Phú, Hải Châu, Đà Nẵng' },
  { n: 2, name: 'Quốc Bảo', daysAgo: 4, lines: [['bun-bo', 1], ['tra-sua', 1]], stars: 5, tags: ['TASTY_FOOD', 'ON_TIME'], comment: 'Bún bò cay vừa, nước dùng thơm sả. Giao đúng giờ.', dropoff: 'Lê Duẩn, Hải Châu, Đà Nẵng' },
  { n: 3, name: 'Thu Hà', daysAgo: 6, lines: [['com-ga', 1], ['ca-phe', 2]], stars: 4, tags: ['WELL_PACKED'], comment: 'Cơm gà giòn, phần ăn hơi ít nhưng gói cẩn thận.', dropoff: 'Nguyễn Văn Linh, Hải Châu, Đà Nẵng' },
  { n: 4, name: 'Hoàng Nam', daysAgo: 9, lines: [['banh-mi', 3], ['ca-phe', 1]], stars: 5, tags: ['TASTY_FOOD', 'ON_TIME', 'FRIENDLY'], comment: 'Bánh mì nóng, pate ngon. Tài xế thân thiện.', dropoff: 'Hùng Vương, Hải Châu, Đà Nẵng' },
  { n: 5, name: 'Lan Phương', daysAgo: 12, lines: [['mi-quang', 1], ['tra-sua', 2]], stars: 4, tags: ['TASTY_FOOD'], comment: 'Trà sữa ngon, trân châu dẻo. Mì Quảng ổn.', dropoff: 'Bạch Đằng, Hải Châu, Đà Nẵng' },
];

const DRIVER_METADATA = {
  seed: APP_REVIEW_SEED_TAG,
  demo: true,
  documentsWaived: true,
  rideService: true,
  foodService: true,
  fullName: 'Tài xế Demo (App Review)',
  birthDate: '1990-01-01',
  address: 'Địa chỉ demo, Hải Châu, Đà Nẵng',
  idNumber: '000000000000',
  licenseClass: 'A1',
  licenseNumber: 'DEMO-000000',
  vehicleClassCode: 'MOTORBIKE',
  vehicleType: 'Xe máy',
  vehiclePlate: '43-DEMO 000.00',
  vehicleBrand: 'Honda',
  vehicleModel: 'Vision (demo)',
  bankName: 'DEMO BANK',
  bankAccountNumber: '0000000000',
  bankAccountHolder: 'DEMO APP REVIEW',
};

const MERCHANT_METADATA = {
  seed: APP_REVIEW_SEED_TAG,
  demo: true,
  documentsWaived: true,
  businessType: 'FOOD_RESTAURANT',
  registrationSubject: 'HOUSEHOLD',
  shopName: APP_REVIEW_STORE_NAME,
  shopAddress: STORE_PIN.label,
  shopLat: STORE_PIN.lat,
  shopLng: STORE_PIN.lng,
  representativeName: 'Chủ quán Demo (App Review)',
  bankName: 'DEMO BANK',
  bankAccountNumber: '0000000000',
  bankAccountHolder: 'DEMO APP REVIEW',
};

/**
 * Deterministic RFC 4122 v5-style id (version + variant bits set, so ParseUUIDPipe accepts it)
 * so re-runs update the same rows and object keys.
 */
export function appReviewId(...parts: string[]): string {
  const h = createHash('sha1').update([APP_REVIEW_SEED_TAG, ...parts].join('|')).digest('hex').slice(0, 32).split('');
  h[12] = '5';
  h[16] = ((parseInt(h[16]!, 16) & 0x3) | 0x8).toString(16);
  const x = h.join('');
  return `${x.slice(0, 8)}-${x.slice(8, 12)}-${x.slice(12, 16)}-${x.slice(16, 20)}-${x.slice(20, 32)}`;
}

export function appReviewDb(): PrismaClient {
  const url = process.env.DATABASE_URL?.trim();
  if (!url) throw new Error('DATABASE_URL is required');
  return new PrismaClient({ adapter: new PrismaPg({ connectionString: url }) });
}

async function main(): Promise<void> {
  assertSeedAllowed(process.env);
  const password = process.env.APP_REVIEW_PASSWORD?.trim() ?? '';
  if (password && password.length < 12) throw new Error('APP_REVIEW_PASSWORD must be at least 12 characters');
  const assetDir = resolve(process.cwd(), process.env.SEED_ASSET_DIR?.trim() || '../design/assets/batch02/png');
  const db = appReviewDb();
  const storage = createObjectStorage(process.env);
  const counts = { uploaded: 0, items: 0, offers: 0, customers: 0, orders: 0, reviews: 0 };

  async function put(key: string, file: string): Promise<void> {
    if (await storage.get(key).catch(() => null)) return;
    // The cover lives with the app's images (mobile/assets/images) unless SEED_ASSET_DIR has it.
    const candidates = [resolve(assetDir, file), resolve(process.cwd(), '../mobile/assets/images', file)];
    const path = candidates.find((c) => existsSync(c)) ?? candidates[0]!;
    await storage.put(key, readFileSync(path), file.endsWith('.jpg') ? 'image/jpeg' : 'image/png');
    counts.uploaded += 1;
  }

  try {
    const region = await db.serviceRegion.findUnique({ where: { code: APP_REVIEW_REGION_CODE } });
    if (!region || region.status !== 'ACTIVE') {
      throw new Error(`service region ${APP_REVIEW_REGION_CODE} must exist and be ACTIVE (zones are not created here)`);
    }
    const now = new Date();

    // 1. User + credential + roles
    const existing = await db.user.findUnique({ where: { email: APP_REVIEW_DEMO_EMAIL } });
    if (existing?.deletedAt) throw new Error('the review account is deleted; restore it in admin or run the cleanup first');
    const user = existing
      ? await db.user.update({
          where: { id: existing.id },
          data: { displayName: APP_REVIEW_DISPLAY_NAME, emailVerifiedAt: existing.emailVerifiedAt ?? now },
        })
      : await db.user.create({
          data: { id: appReviewId('user'), email: APP_REVIEW_DEMO_EMAIL, displayName: APP_REVIEW_DISPLAY_NAME, emailVerifiedAt: now },
        });
    const credential = await db.customerCredential.findUnique({ where: { userId: user.id } });
    if (password) {
      const passwordHash = await argon2Hash(password, { type: argon2id });
      await db.customerCredential.upsert({ where: { userId: user.id }, create: { userId: user.id, passwordHash }, update: { passwordHash } });
    } else if (!credential) {
      throw new Error('the review account has no password yet: set APP_REVIEW_PASSWORD for this run');
    }
    for (const role of ['CUSTOMER', 'DRIVER', 'MERCHANT'] as const) {
      await db.roleGrant.upsert({
        where: { userId_role: { userId: user.id, role } },
        create: { userId: user.id, role, status: 'ACTIVE' },
        update: { status: 'ACTIVE' },
      });
    }

    // 2. Approved partner applications (fake demo KYC, no document files)
    for (const [role, metadata] of [['DRIVER', DRIVER_METADATA], ['MERCHANT', MERCHANT_METADATA]] as const) {
      await db.partnerApplication.upsert({
        where: { userId_role: { userId: user.id, role } },
        create: { userId: user.id, role, status: 'APPROVED', metadata, documents: [], submittedAt: now, reviewedAt: now },
        update: { status: 'APPROVED', metadata, reviewIssues: [], reason: null },
      });
    }
    // Offline until the reviewer goes online; a re-run never changes the current online state.
    await db.driverPresence.upsert({
      where: { userId: user.id },
      create: { userId: user.id, online: false, lat: STORE_PIN.lat, lng: STORE_PIN.lng, locationAt: now, serviceRegionCode: region.code },
      update: { serviceRegionCode: region.code },
    });

    // 3. Store, menu, images
    const storeId = appReviewId('store');
    const other = await db.foodStore.findUnique({ where: { id: storeId } });
    if (other && other.ownerId !== user.id) throw new Error('demo store id is owned by another user');
    const logoKey = `store-logos/${storeId}/${appReviewId('logo', STORE_LOGO)}.png`;
    const coverKey = `store-covers/${storeId}/${appReviewId('cover', STORE_COVER)}.jpg`;
    const storeData = {
      name: APP_REVIEW_STORE_NAME,
      category: 'noodles',
      lat: STORE_PIN.lat,
      lng: STORE_PIN.lng,
      serviceRegionCode: region.code,
      addressLabel: STORE_PIN.label,
      logoUrl: storeLogoPath(storeId, logoKey),
      coverUrl: storeLogoPath(storeId, coverKey, 'cover'),
      description: STORE_DESCRIPTION,
      serviceMode: 'OPEN' as const,
      serviceModeUntil: null,
      hoursConfigured: true,
      lastOrderMinutes: 0,
      defaultPrepMinutes: 12,
      minOrderVnd: 25000,
    };
    await db.foodStore.upsert({ where: { id: storeId }, create: { id: storeId, ownerId: user.id, ...storeData }, update: storeData });
    await put(logoKey, STORE_LOGO);
    await put(coverKey, STORE_COVER);
    // Weekly hours 00:00–24:00 Mon..Sun: a real schedule on screen, yet orderable at any hour.
    for (let weekday = 1; weekday <= 7; weekday += 1) {
      await db.foodStoreHour.upsert({
        where: { storeId_weekday: { storeId, weekday } },
        create: { storeId, weekday, opensMinute: 0, closesMinute: 1440 },
        update: { opensMinute: 0, closesMinute: 1440 },
      });
    }

    const categoryIds: Record<string, string> = {};
    for (const c of CATEGORIES) {
      const id = appReviewId('category', c.key);
      categoryIds[c.key] = id;
      await db.foodMenuCategory.upsert({
        where: { id },
        create: { id, storeId, name: c.name, position: c.position },
        update: { name: c.name, position: c.position },
      });
    }
    const itemIds: Record<string, string> = {};
    const itemPaths: Record<string, string> = {};
    const soldTarget: Record<string, number> = {};
    for (const r of REVIEWS) for (const [k, q] of r.lines) soldTarget[k] = (soldTarget[k] ?? 0) + q;
    for (const it of ITEMS) {
      const id = appReviewId('item', it.key);
      itemIds[it.key] = id;
      const key = `menu-items/${id}/${appReviewId('item-image', it.key, it.image)}.png`;
      await put(key, it.image);
      const path = menuItemImagePath(id, key);
      itemPaths[it.key] = path;
      const current = await db.foodItem.findUnique({ where: { id }, select: { soldCount: true } });
      const data = {
        menuCategoryId: categoryIds[it.category]!,
        name: it.name,
        description: it.description,
        priceVnd: it.priceVnd,
        originalPriceVnd: it.originalPriceVnd ?? null,
        prepMinutes: it.prepMinutes,
        soldCount: Math.max(current?.soldCount ?? 0, soldTarget[it.key] ?? 0),
        createdAt: new Date(now.getTime() - (it.fresh ? 1 : 60) * DAY_MS),
        imageUrl: path,
        imageUrls: [path],
        available: true,
        moderationStatus: 'APPROVED' as const,
      };
      await db.foodItem.upsert({ where: { id }, create: { id, storeId, ...data }, update: data });
      counts.items += 1;
    }

    // 4. Store vouchers (by code; usedCount / usedBudget are left to real redemptions)
    for (const o of OFFERS) {
      const perUseCap = o.discountType === 'FIXED_AMOUNT' ? o.discountValue : (o.maxDiscountAmount ?? 0);
      const data = {
        name: o.name,
        description: '',
        serviceType: 'FOOD' as const,
        discountType: o.discountType,
        discountValue: o.discountValue,
        maxDiscountAmount: o.maxDiscountAmount,
        minOrderAmount: o.minOrderAmount,
        totalBudget: perUseCap * o.usageLimit,
        usageLimit: o.usageLimit,
        userLimit: 1,
        targetAudience: 'CUSTOMER' as const,
        status: 'ACTIVE' as const,
        startDate: new Date(now.getTime() - DAY_MS),
        endDate: new Date(now.getTime() + OFFER_DAYS * DAY_MS),
        sponsor: 'MERCHANT' as const,
        storeId,
      };
      const taken = await db.promotion.findUnique({ where: { code: o.code }, select: { storeId: true } });
      if (taken && taken.storeId !== storeId) throw new Error(`voucher code ${o.code} belongs to another campaign`);
      await db.promotion.upsert({ where: { code: o.code }, create: { id: appReviewId('offer', o.code), code: o.code, ...data }, update: data });
      counts.offers += 1;
    }

    // 5. Demo customers, their delivered orders and reviews (one reply from the store)
    for (const r of REVIEWS) {
      const email = `${APP_REVIEW_CUSTOMER_EMAIL_PREFIX}${r.n}${APP_REVIEW_CUSTOMER_EMAIL_DOMAIN}`;
      const customerId = appReviewId('customer', String(r.n));
      const found = await db.user.findUnique({ where: { email }, select: { id: true } });
      if (found && found.id !== customerId) throw new Error(`${email} exists with another id`);
      const displayName = `${r.name} (demo)`;
      await db.user.upsert({
        where: { id: customerId },
        create: { id: customerId, email, displayName, emailVerifiedAt: now },
        update: { displayName },
      });
      await db.roleGrant.upsert({
        where: { userId_role: { userId: customerId, role: 'CUSTOMER' } },
        create: { userId: customerId, role: 'CUSTOMER', status: 'ACTIVE' },
        update: {},
      });
      counts.customers += 1;

      const orderId = appReviewId('order', String(r.n));
      const placedAt = new Date(now.getTime() - r.daysAgo * DAY_MS);
      const minutes = (m: number) => new Date(placedAt.getTime() + m * 60_000);
      const lines = r.lines.map(([k, quantity]) => {
        const it = ITEMS.find((x) => x.key === k)!;
        return { itemId: itemIds[k]!, name: it.name, unitPriceVnd: it.priceVnd, quantity, imageUrl: itemPaths[k]! };
      });
      const subtotalVnd = lines.reduce((sum, l) => sum + l.unitPriceVnd * l.quantity, 0);
      const order = {
        status: 'DELIVERED' as const,
        deliveryFareVnd: DELIVERY_FARE_VND,
        subtotalVnd,
        totalVnd: subtotalVnd + DELIVERY_FARE_VND,
        dropoffLat: STORE_PIN.lat + 0.004 * r.n,
        dropoffLng: STORE_PIN.lng - 0.003 * r.n,
        dropoffLabel: r.dropoff,
        pickupLat: STORE_PIN.lat,
        pickupLng: STORE_PIN.lng,
        pickupLabel: STORE_PIN.label,
        serviceRegionCode: region.code,
        prepMinutes: 12,
        acceptedAt: minutes(1),
        readyAt: minutes(13),
        pickedUpAt: minutes(16),
        merchantCashVnd: subtotalVnd,
        createdAt: placedAt,
      };
      await db.foodOrder.upsert({
        where: { id: orderId },
        create: { id: orderId, customerId, storeId, idempotencyKey: `${APP_REVIEW_SEED_TAG}-order-${r.n}`, ...order },
        update: order,
      });
      await db.foodOrderLine.deleteMany({ where: { orderId } });
      await db.foodOrderLine.createMany({
        data: lines.map((l, i) => ({ id: appReviewId('order-line', String(r.n), String(i)), orderId, ...l })),
      });
      counts.orders += 1;

      const rating = {
        raterId: customerId,
        storeId,
        storeStars: r.stars,
        tags: r.tags,
        comment: r.comment,
        createdAt: minutes(45),
        merchantReply: r.reply ?? null,
        repliedAt: r.reply ? minutes(180) : null,
        hiddenAt: null,
        hiddenReason: null,
      };
      await db.serviceRating.upsert({
        where: { subjectType_subjectId: { subjectType: 'FOOD_ORDER', subjectId: orderId } },
        create: { id: appReviewId('rating', String(r.n)), subjectType: 'FOOD_ORDER', subjectId: orderId, ...rating },
        update: rating,
      });
      counts.reviews += 1;
    }

    // 6. Review login switch (DEC-PROD-052)
    for (const [key, value, valueType] of [
      ['APP_REVIEW_LOGIN_ENABLED', 'true', 'json'],
      ['APP_REVIEW_EMAIL', APP_REVIEW_DEMO_EMAIL, 'string'],
    ] as const) {
      await db.platformSetting.upsert({ where: { key }, create: { key, value, valueType }, update: { value } });
    }

    console.log(
      JSON.stringify(
        { seed: APP_REVIEW_SEED_TAG, userId: user.id, storeId, region: region.code, storage: storage.provider, passwordSet: Boolean(password), ...counts },
        null,
        2,
      ),
    );
  } finally {
    await db.$disconnect();
  }
}

if (process.argv[1]?.endsWith('seed-app-review.ts')) {
  main().catch((error: unknown) => {
    console.error(error instanceof Error ? error.message : error);
    process.exitCode = 1;
  });
}
