/**
 * Synchronizes updated design assets (vehicle classes, home banners, food categories)
 * to Cloudflare R2 / ObjectStorage and updates their public URLs in PostgreSQL.
 *
 * Generates fresh UUIDs for updated assets to bust Cloudflare edge CDN and client caches.
 *
 * Usage:
 *   npx tsx scripts/sync-updated-assets.ts
 */
import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { randomUUID } from 'node:crypto';
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '../src/generated/prisma/client.js';
import { createObjectStorage } from '../src/platform/storage/storage.module.js';
import {
  PUBLIC_IMAGE_VARIANT_WIDTHS,
  imageVariantKey,
  toPublicWebp,
  toVariantWebp,
} from '../src/platform/storage/image-variants.js';
import { rideVehicleClassImagePath } from '../src/modules/ride-vehicle/ride-vehicle-class-image.js';
import { homeBannerImagePath } from '../src/modules/home-banner/home-banner.js';
import { foodCategoryImagePath } from '../src/modules/food-category/food-category.js';

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
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }
    process.env[key] = value;
  }
}

const BATCH02_DIR = resolve(process.cwd(), '../design/assets/batch02/png');
const BATCH01_DIR = resolve(process.cwd(), '../design/assets/batch01/png');
const MOBILE_IMG_DIR = resolve(process.cwd(), '../mobile/assets/images');

function resolveAssetPath(file: string, fallback?: string): string {
  const candidates = [
    resolve(BATCH02_DIR, file),
    resolve(BATCH01_DIR, file),
    resolve(MOBILE_IMG_DIR, file),
    ...(fallback
      ? [
          resolve(BATCH02_DIR, fallback),
          resolve(BATCH01_DIR, fallback),
          resolve(MOBILE_IMG_DIR, fallback),
        ]
      : []),
  ];
  for (const candidate of candidates) {
    if (candidate && existsSync(candidate)) return candidate;
  }
  throw new Error(`Asset not found: ${file} (fallback: ${fallback ?? 'none'})`);
}

async function main(): Promise<void> {
  loadDotEnv();

  const databaseUrl = process.env.DATABASE_URL;
  if (!databaseUrl) {
    throw new Error('DATABASE_URL is required');
  }

  const db = new PrismaClient({
    adapter: new PrismaPg({ connectionString: databaseUrl }),
  });

  const storage = createObjectStorage(process.env);
  console.log('ObjectStorage initialized');

  const uploadAndVariant = async (
    storageKeyPrefix: string,
    file: string,
    fallback?: string,
  ): Promise<string> => {
    const fullPath = resolveAssetPath(file, fallback);
    const source = readFileSync(fullPath);
    const normalized = await toPublicWebp(source);
    if (!normalized) {
      throw new Error(`Failed to convert ${fullPath} to webp`);
    }

    const fileUuid = randomUUID();
    const storedKey = `${storageKeyPrefix}/${fileUuid}.webp`;

    await storage.put(storedKey, normalized.body, 'image/webp');
    console.log(`  Uploaded: ${storedKey} (${(normalized.body.byteLength / 1024).toFixed(1)} KB, ${normalized.width}x${normalized.height})`);

    for (const width of PUBLIC_IMAGE_VARIANT_WIDTHS) {
      if (normalized.width <= width) continue;
      const variantKey = imageVariantKey(storedKey, width);
      if (!variantKey) continue;
      const variant = await toVariantWebp(normalized.body, width);
      if (variant) {
        await storage.put(variantKey, variant, 'image/webp');
        console.log(`    Variant: ${variantKey} (${(variant.byteLength / 1024).toFixed(1)} KB)`);
      }
    }

    return storedKey;
  };

  try {
    // 1. Sync Ride Vehicle Classes
    console.log('\n--- 1. Syncing Ride Vehicle Classes ---');
    const vehicleImages: Record<string, { file: string; fallback?: string }> = {
      MOTORBIKE: { file: 'vehicle_scooter_green.png', fallback: 'vehicle_motorbike.png' },
      CAR_4: { file: 'vehicle_car_4.png', fallback: 'vehicle_scooter_white.png' },
      CAR_7: { file: 'vehicle_car_7.png', fallback: 'vehicle_scooter_red.png' },
    };

    for (const [code, spec] of Object.entries(vehicleImages)) {
      const existing = await db.rideVehicleClass.findUnique({ where: { code } });
      if (!existing) {
        console.log(`  Skipping ${code} (not found in DB)`);
        continue;
      }
      const storedKey = await uploadAndVariant(`ride-vehicle-classes/${code}`, spec.file, spec.fallback);
      const imageUrl = rideVehicleClassImagePath(code, storedKey);
      await db.rideVehicleClass.update({
        where: { code },
        data: { imageUrl, enabled: true },
      });
      console.log(`  Updated ${code} -> ${imageUrl}`);
    }

    // 2. Sync Home Banners
    console.log('\n--- 2. Syncing Home Banners ---');
    const bannerSpecs = [
      {
        id: '779a8898-3414-463f-a09c-5b9a9eef986e',
        file: 'banner_ride_dealgo.png',
        fallback: 'banner_ride_dealgo.png',
      },
      {
        id: '5b83bb66-a362-4a36-9812-c1a66ed69a0a',
        file: 'banner_food_dealgo.png',
        fallback: 'banner_food_dealgo.png',
      },
      {
        id: '1341e246-1efd-4e61-ad61-52bda6ded683',
        file: 'banner_promo_dealgo.png',
        fallback: 'banner_promo_dealgo.png',
      },
      {
        id: '2d74aca5-2073-529a-ba60-3230bbf485f1',
        file: 'banner_driver_dealgo.png',
        fallback: 'banner_driver_dealgo.png',
      },
      {
        id: 'e84a550f-fb95-567d-bda6-20dffa6bddb5',
        file: 'banner_merchant_dealgo.png',
        fallback: 'banner_merchant_dealgo.png',
      },
    ];

    for (const banner of bannerSpecs) {
      const existing = await db.homeBanner.findUnique({ where: { id: banner.id } });
      if (!existing) {
        console.log(`  Skipping banner ${banner.id} (not found in DB)`);
        continue;
      }
      const storedKey = await uploadAndVariant(`home-banners/${banner.id}`, banner.file, banner.fallback);
      const imageUrl = homeBannerImagePath(banner.id, storedKey);
      await db.homeBanner.update({
        where: { id: banner.id },
        data: { imageUrl, active: true },
      });
      console.log(`  Updated banner ${banner.id} -> ${imageUrl}`);
    }

    // 3. Sync Food Categories
    console.log('\n--- 3. Syncing Food Categories ---');
    const categoryImages: Record<string, { file: string; fallback?: string }> = {
      pho: { file: 'food_pho_bo.png', fallback: 'food_bun_bo_hue.png' },
      noodles: { file: 'food_mi_quang.png', fallback: 'food_mi_quang.png' },
      rice: { file: 'food_grilled_rice.png', fallback: 'food_grilled_rice.png' },
      banh_mi: { file: 'food_banh_mi.png', fallback: 'food_banh_mi.png' },
      tea: { file: 'food_tra_sua.png', fallback: 'food_tra_sua.png' },
      cafe: { file: 'food_coffee.png', fallback: 'food_coffee.png' },
      fast_food: { file: 'food_fast_food_burger.png', fallback: 'food_pizza.png' },
      snack: { file: 'food_snack_platter.png', fallback: 'food_seafood.png' },
      mart: { file: 'food_fresh_grocery.png', fallback: 'store_supermarket.png' },
    };

    for (const [code, spec] of Object.entries(categoryImages)) {
      const existing = await db.foodCategory.findUnique({ where: { code } });
      if (!existing) {
        console.log(`  Skipping category ${code} (not found in DB)`);
        continue;
      }
      const storedKey = await uploadAndVariant(`food-categories/${code}`, spec.file, spec.fallback);
      const imageUrl = foodCategoryImagePath(code, storedKey);
      await db.foodCategory.update({
        where: { code },
        data: { imageUrl, active: true },
      });
      console.log(`  Updated category ${code} -> ${imageUrl}`);
    }

    console.log('\nAsset synchronization completed successfully!');
  } finally {
    await db.$disconnect();
  }
}

main().catch((err) => {
  console.error('Error syncing assets:', err);
  process.exitCode = 1;
});
