/**
 * DEV-only showcase seed. Idempotent: run as often as you like.
 *
 *  - Vietnamese store logos + menu images from local files in design/assets/batch02/png,
 *    written through the app's ObjectStorage (same keys/URLs as real uploads).
 *  - Renames the merchant smoke store (+84909990011) to a presentable name.
 *  - MOTORBIKE / CAR_4 / CAR_7 drivers (approved DRIVER application + online presence).
 *  - Customer history for +84909990101: completed rides + delivered food orders + ratings.
 *
 * Fares are never hard-coded: ride fares come from the DB ride_vehicle_classes rows
 * (DRAFT / ADMIN_EDITABLE, OPEN-003) and delivery fares from FOOD_* platform settings.
 * Refuses to run against production or a non-local database.
 */
import { createHash } from 'node:crypto';
import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '../src/generated/prisma/client.js';
import { createObjectStorage } from '../src/platform/storage/storage.module.js';
import { menuItemImagePath } from '../src/modules/catalog/menu-item-image.service.js';
import { storeLogoPath } from '../src/modules/catalog/store-logo.service.js';
import { quoteVehicleClassFare } from '../src/modules/ride-vehicle/ride-vehicle-class.js';
import { haversineKm } from '../src/shared/geo/haversine.js';

const IMG_DIR = resolve(process.cwd(), '../design/assets/batch02/png');

function loadDotEnv(): void {
  const envFile = resolve(process.cwd(), '.env');
  if (!existsSync(envFile)) return;
  for (const raw of readFileSync(envFile, 'utf8').split('\n')) {
    const line = raw.trim();
    if (!line || line.startsWith('#')) continue;
    const eq = line.indexOf('=');
    if (eq <= 0) continue;
    const key = line.slice(0, eq).trim();
    if (process.env[key] !== undefined) continue;
    let value = line.slice(eq + 1).trim();
    if ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'"))) {
      value = value.slice(1, -1);
    }
    process.env[key] = value;
  }
}

/** Deterministic UUID-shaped id so re-runs reuse the same object keys. */
export function stableUuid(...parts: string[]): string {
  const h = createHash('sha1').update(parts.join('|')).digest('hex');
  return `${h.slice(0, 8)}-${h.slice(8, 12)}-${h.slice(12, 16)}-${h.slice(16, 20)}-${h.slice(20, 32)}`;
}

export function assertDevDatabase(url: string, nodeEnv: string | undefined): void {
  if (nodeEnv === 'production') throw new Error('seed-dev-showcase refuses NODE_ENV=production');
  const host = (() => {
    try {
      return new URL(url).hostname;
    } catch {
      return '';
    }
  })();
  if (!['localhost', '127.0.0.1', 'postgres', '::1'].includes(host)) {
    throw new Error('seed-dev-showcase only runs against a local DEV database');
  }
}

type StoreSpec = {
  match: { name?: string; ownerPhone?: string };
  rename?: string;
  logo: string;
  addressLabel?: string;
  lat?: number;
  lng?: number;
  category?: string;
  items: Array<{ name: string; image: string; priceVnd?: number; description?: string }>;
};

// Menu prices are merchant sample data (DEV), not platform tariffs.
const STORES: StoreSpec[] = [
  {
    match: { name: 'Cơm Tấm Ba Ghiền — Quận 1' },
    logo: 'food_grilled_rice.png',
    items: [{ name: '*', image: 'food_grilled_rice.png' }, { name: '*', image: 'food_grilled_meat.png' }],
  },
  {
    match: { name: 'Trà Sữa Phúc Long — Thảo Điền' },
    logo: 'store_coffee_shop.png',
    items: [{ name: '*', image: 'food_tra_sua.png' }, { name: '*', image: 'food_coffee.png' }],
  },
  {
    match: { name: 'Cà Phê Sài Gòn — Bitexco' },
    logo: 'food_coffee.png',
    items: [{ name: '*', image: 'food_coffee.png' }, { name: '*', image: 'food_banh_mi.png' }],
  },
  {
    match: { name: 'Mì Quảng Bà Mua — Hải Châu Đà Nẵng' },
    logo: 'store_noodle_shop.png',
    items: [{ name: '*', image: 'food_mi_quang.png' }, { name: '*', image: 'food_seafood.png' }],
  },
  {
    match: { name: 'Bún Bò Huế — Nguyễn Huệ' },
    logo: 'food_bun_bo_hue.png',
    items: [{ name: '*', image: 'food_bun_bo_hue.png' }, { name: '*', image: 'food_bun_bo_special.png' }],
  },
  {
    match: { ownerPhone: '+84909990011' },
    rename: 'Quán Cơm Nhà Làm — Hải Châu',
    logo: 'store_noodle_shop.png',
    addressLabel: '120 Bạch Đằng, Hải Châu, Đà Nẵng',
    category: 'Cơm',
    items: [
      { name: 'Cơm gà xối mỡ', image: 'food_grilled_meat.png', priceVnd: 45000, description: 'Gà giòn, cơm chiên nhẹ, đồ chua.' },
      { name: 'Bún thịt nướng', image: 'food_bun_home.png', priceVnd: 40000, description: 'Thịt nướng than, rau sống, nước mắm chua ngọt.' },
      { name: 'Bánh mì thịt', image: 'food_banh_mi.png', priceVnd: 25000, description: 'Pate, chả lụa, thịt nguội.' },
      { name: 'Cơm tấm sườn', image: 'food_grilled_rice.png', priceVnd: 50000, description: 'Sườn nướng, bì, chả trứng.' },
    ],
  },
];

const DRIVERS = [
  { phone: '+84908880001', name: 'Nguyễn Văn Hùng', cls: 'MOTORBIKE', vehicle: 'Honda Vision 110cc', plate: '43-D1 123.45', lat: 16.0678, lng: 108.2208 },
  { phone: '+84908880002', name: 'Phạm Minh Tuấn', cls: 'MOTORBIKE', vehicle: 'Yamaha Exciter 155', plate: '43-E1 567.89', lat: 16.0605, lng: 108.2241 },
  { phone: '+84908880003', name: 'Trần Quốc Việt', cls: 'CAR_4', vehicle: 'Toyota Vios (4 chỗ)', plate: '43A-678.90', lat: 16.0712, lng: 108.2179 },
  { phone: '+84908880004', name: 'Lê Hoàng Nam', cls: 'CAR_7', vehicle: 'Mitsubishi Xpander (7 chỗ)', plate: '43A-246.80', lat: 16.0551, lng: 108.2163 },
] as const;

const CUSTOMER_PHONE = '+84909990101';

async function ensureUser(db: PrismaClient, phone: string, displayName: string): Promise<string> {
  const found = await db.user.findFirst({ where: { phone } });
  if (found) {
    if (!found.displayName) await db.user.update({ where: { id: found.id }, data: { displayName } });
    return found.id;
  }
  const created = await db.user.create({ data: { phone, displayName, phoneVerifiedAt: new Date() } as any });
  return created.id;
}

async function main(): Promise<void> {
  loadDotEnv();
  const url = process.env.DATABASE_URL?.trim() || 'postgresql://localhost:5432/dealgo';
  assertDevDatabase(url, process.env.NODE_ENV);
  const db = new PrismaClient({ adapter: new PrismaPg({ connectionString: url }) });
  const storage = createObjectStorage(process.env as any);
  const counts = { logos: 0, itemImages: 0, uploaded: 0, drivers: 0, rides: 0, foodOrders: 0, ratings: 0 };
  const uploadedKeys = new Set<string>();

  async function put(key: string, file: string): Promise<void> {
    if (uploadedKeys.has(key)) return;
    const existing = await storage.get(key).catch(() => null);
    if (!existing) {
      await storage.put(key, readFileSync(resolve(IMG_DIR, file)), 'image/png');
      counts.uploaded += 1;
    }
    uploadedKeys.add(key);
  }

  try {
    // 1. Stores + images
    const storeIds: Record<string, string> = {};
    for (const spec of STORES) {
      const store = spec.match.name
        ? await db.foodStore.findFirst({ where: { name: spec.match.name } })
        : await db.foodStore.findFirst({ where: { owner: { phone: spec.match.ownerPhone } }, orderBy: { createdAt: 'asc' } });
      if (!store) {
        console.warn(`skip: store not found ${JSON.stringify(spec.match)} (run npm run seed first)`);
        continue;
      }
      storeIds[spec.rename ?? store.name] = store.id;
      const logoKey = `store-logos/${store.id}/${stableUuid('logo', store.id, spec.logo)}.png`;
      await put(logoKey, spec.logo);
      await db.foodStore.update({
        where: { id: store.id },
        data: {
          logoUrl: storeLogoPath(store.id, logoKey),
          ...(spec.rename ? { name: spec.rename } : {}),
          ...(spec.addressLabel ? { addressLabel: spec.addressLabel } : {}),
          ...(spec.category ? { category: spec.category } : {}),
        },
      });
      counts.logos += 1;

      const named = spec.items.filter((i) => i.name !== '*');
      for (const it of named) {
        const found = await db.foodItem.findFirst({ where: { storeId: store.id, name: it.name } });
        if (!found) {
          await db.foodItem.create({
            data: { storeId: store.id, name: it.name, priceVnd: it.priceVnd ?? 0, description: it.description ?? null, available: true },
          });
        } else if (it.description && !found.description) {
          await db.foodItem.update({ where: { id: found.id }, data: { description: it.description } });
        }
      }
      const items = await db.foodItem.findMany({ where: { storeId: store.id }, orderBy: { name: 'asc' } });
      const pool = spec.items.map((i) => i.image);
      for (const [idx, item] of items.entries()) {
        const image = named.find((n) => n.name === item.name)?.image ?? pool[idx % pool.length]!;
        const key = `menu-items/${item.id}/${stableUuid('item', item.id, image)}.png`;
        await put(key, image);
        const path = menuItemImagePath(item.id, key);
        await db.foodItem.update({ where: { id: item.id }, data: { imageUrl: path, imageUrls: [path] } });
        counts.itemImages += 1;
      }
    }

    // 2. Drivers
    const driverIds: Record<string, string> = {};
    for (const d of DRIVERS) {
      const id = await ensureUser(db, d.phone, d.name);
      driverIds[d.cls + d.phone] = id;
      for (const role of ['CUSTOMER', 'DRIVER'] as const) {
        await db.roleGrant.upsert({ where: { userId_role: { userId: id, role } }, create: { userId: id, role, status: 'ACTIVE' }, update: { status: 'ACTIVE' } });
      }
      const metadata = { vehicleType: d.vehicle, vehicleClassCode: d.cls, plateNumber: d.plate, city: 'Đà Nẵng', seed: 'dev-showcase' };
      await db.partnerApplication.upsert({
        where: { userId_role: { userId: id, role: 'DRIVER' } },
        create: { userId: id, role: 'DRIVER', status: 'APPROVED', metadata, submittedAt: new Date(), reviewedAt: new Date() },
        update: { status: 'APPROVED', metadata },
      });
      await db.driverPresence.upsert({
        where: { userId: id },
        create: { userId: id, online: true, lat: d.lat, lng: d.lng, locationAt: new Date(), serviceRegionCode: 'DN' },
        update: { online: true, lat: d.lat, lng: d.lng, locationAt: new Date() },
      });
      counts.drivers += 1;
    }

    // 3. Customer history
    const customerId = await ensureUser(db, CUSTOMER_PHONE, 'Khách DealGo');
    const classes = new Map((await db.rideVehicleClass.findMany()).map((c) => [c.code, c]));
    const ids = Object.values(driverIds);
    const rides = [
      { key: 'showcase-ride-1', cls: 'MOTORBIKE', driver: ids[0]!, days: 1, stars: 5, tags: ['Đúng giờ', 'Thân thiện'], comment: 'Anh tài xế chạy cẩn thận.',
        pickup: { lat: 16.0678, lng: 108.2208, label: 'Cầu Rồng, Hải Châu' }, dropoff: { lat: 16.0544, lng: 108.2022, label: 'Sân bay Đà Nẵng' } },
      { key: 'showcase-ride-2', cls: 'CAR_4', driver: ids[2]!, days: 3, stars: 5, tags: ['Xe sạch'], comment: null,
        pickup: { lat: 16.0471, lng: 108.2468, label: 'Bãi biển Mỹ Khê' }, dropoff: { lat: 16.0717, lng: 108.2236, label: 'Chợ Hàn' } },
      { key: 'showcase-ride-3', cls: 'MOTORBIKE', driver: ids[1]!, days: 6, stars: 4, tags: ['Đúng giờ'], comment: null,
        pickup: { lat: 16.0605, lng: 108.2241, label: 'Vincom Ngô Quyền' }, dropoff: { lat: 16.0743, lng: 108.1500, label: 'ĐH Bách Khoa Đà Nẵng' } },
    ];
    for (const r of rides) {
      const vc = classes.get(r.cls);
      if (!vc) {
        console.warn(`skip ride ${r.key}: vehicle class ${r.cls} missing`);
        continue;
      }
      const fare = quoteVehicleClassFare({ distanceKm: haversineKm(r.pickup, r.dropoff), vehicle: vc }).referenceFareVnd;
      const at = new Date(Date.now() - r.days * 86400_000);
      const data = {
        status: 'COMPLETED' as const, vehicleClassCode: r.cls, assignedDriverId: r.driver,
        pickupLat: r.pickup.lat, pickupLng: r.pickup.lng, pickupLabel: r.pickup.label,
        dropoffLat: r.dropoff.lat, dropoffLng: r.dropoff.lng, dropoffLabel: r.dropoff.label,
        offeredFareVnd: fare, referenceFareVnd: fare, agreedFareVnd: fare, expiresAt: at, serviceRegionCode: 'DN',
      };
      const ride = await db.ride.upsert({
        where: { customerId_idempotencyKey: { customerId, idempotencyKey: r.key } },
        create: { customerId, idempotencyKey: r.key, ...data, createdAt: at },
        update: data,
      });
      counts.rides += 1;
      await db.serviceRating.upsert({
        where: { subjectType_subjectId: { subjectType: 'RIDE', subjectId: ride.id } },
        create: { subjectType: 'RIDE', subjectId: ride.id, raterId: customerId, driverId: r.driver, driverStars: r.stars, tags: r.tags, comment: r.comment, createdAt: at },
        update: { driverStars: r.stars, tags: r.tags, comment: r.comment },
      });
      counts.ratings += 1;
    }

    const setting = async (key: string): Promise<number> => Number((await db.platformSetting.findUnique({ where: { key } }))?.value ?? NaN);
    const [minD, maxD, perKm] = await Promise.all(['FOOD_MIN_DELIVERY_VND', 'FOOD_MAX_DELIVERY_VND', 'FOOD_DELIVERY_VND_PER_KM'].map(setting));
    const dropoff = { lat: 16.0611, lng: 108.2290, label: '25 Trần Phú, Hải Châu, Đà Nẵng' };
    const orders = [
      { key: 'showcase-food-1', store: 'Mì Quảng Bà Mua — Hải Châu Đà Nẵng', days: 2, stars: 5, tags: ['Ngon', 'Đóng gói kỹ'], comment: 'Mì Quảng chuẩn vị.' },
      { key: 'showcase-food-2', store: 'Quán Cơm Nhà Làm — Hải Châu', days: 4, stars: 5, tags: ['Ngon'], comment: null },
      { key: 'showcase-food-3', store: 'Bún Bò Huế — Nguyễn Huệ', days: 8, stars: 4, tags: ['Giao nhanh'], comment: null },
    ];
    for (const o of orders) {
      const storeId = storeIds[o.store];
      if (!storeId || ![minD, maxD, perKm].every(Number.isFinite)) {
        console.warn(`skip order ${o.key}: store or FOOD_* settings missing`);
        continue;
      }
      const store = await db.foodStore.findUniqueOrThrow({ where: { id: storeId }, include: { items: { take: 2, orderBy: { name: 'asc' } } } });
      const km = store.lat != null && store.lng != null ? haversineKm({ lat: store.lat, lng: store.lng }, dropoff) : 0;
      const deliveryFareVnd = Math.min(maxD, Math.max(minD, Math.round(km * perKm)));
      const lines = store.items.map((it, i) => ({ itemId: it.id, name: it.name, unitPriceVnd: it.priceVnd, quantity: i === 0 ? 2 : 1 }));
      const subtotalVnd = lines.reduce((s, l) => s + l.unitPriceVnd * l.quantity, 0);
      const at = new Date(Date.now() - o.days * 86400_000);
      const data = {
        storeId, status: 'DELIVERED' as const, deliveryFareVnd, subtotalVnd, totalVnd: subtotalVnd + deliveryFareVnd,
        dropoffLat: dropoff.lat, dropoffLng: dropoff.lng, dropoffLabel: dropoff.label,
        pickupLat: store.lat, pickupLng: store.lng, pickupLabel: store.addressLabel, assignedDriverId: ids[0]!,
      };
      const existing = await db.foodOrder.findUnique({ where: { customerId_idempotencyKey: { customerId, idempotencyKey: o.key } } });
      let orderId: string;
      if (existing) {
        await db.foodOrderLine.deleteMany({ where: { orderId: existing.id } });
        await db.foodOrder.update({ where: { id: existing.id }, data: { ...data, lines: { create: lines } } });
        orderId = existing.id;
      } else {
        orderId = (await db.foodOrder.create({ data: { customerId, idempotencyKey: o.key, ...data, createdAt: at, lines: { create: lines } } })).id;
      }
      counts.foodOrders += 1;
      await db.serviceRating.upsert({
        where: { subjectType_subjectId: { subjectType: 'FOOD_ORDER', subjectId: orderId } },
        create: { subjectType: 'FOOD_ORDER', subjectId: orderId, raterId: customerId, storeId, storeStars: o.stars, driverId: ids[0]!, driverStars: 5, tags: o.tags, comment: o.comment, createdAt: at },
        update: { storeStars: o.stars, tags: o.tags, comment: o.comment },
      });
      counts.ratings += 1;
    }
    console.log(JSON.stringify({ seed: 'dev-showcase', storage: storage.provider, ...counts }, null, 2));
  } finally {
    await db.$disconnect();
  }
}

if (process.argv[1]?.endsWith('seed-dev-showcase.ts')) {
  main().catch((error: unknown) => {
    console.error(error instanceof Error ? error.message : error);
    process.exitCode = 1;
  });
}
