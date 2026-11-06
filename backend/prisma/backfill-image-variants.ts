/**
 * One-off migration for photos uploaded before width variants existed: every public image is
 * re-encoded to WebP and gets a variant per display width, then the rows that point at the old
 * file are rewritten to the WebP object. Old objects are left in place; the orphan cleanup
 * worker removes them once nothing references them.
 *
 *   npx tsx prisma/backfill-image-variants.ts            # report only
 *   IMAGE_BACKFILL_APPLY=1 npx tsx prisma/backfill-image-variants.ts
 */
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '../src/generated/prisma/client.js';
import {
  PUBLIC_IMAGE_VARIANT_WIDTHS,
  imageVariantKey,
  readImageSize,
  toPublicWebp,
  toVariantWebp,
} from '../src/platform/storage/image-variants.js';
import { createObjectStorage } from '../src/platform/storage/storage.module.js';
import { keyFromAvatarUrl } from '../src/modules/avatar/avatar.service.js';
import { keyFromMenuItemImageUrl } from '../src/modules/catalog/menu-item-image.service.js';
import { keyFromStoreLogoUrl } from '../src/modules/catalog/store-logo.service.js';
import { keyFromRideVehicleClassImageUrl } from '../src/modules/ride-vehicle/ride-vehicle-class-image.js';
import { keyFromHomeBannerImageUrl } from '../src/modules/home-banner/home-banner.js';
import { keyFromFoodCategoryImageUrl } from '../src/modules/food-category/food-category.js';

const APPLY = process.env.IMAGE_BACKFILL_APPLY === '1';

function loadEnv(): void {
  try {
    process.loadEnvFile();
  } catch {
    // Already exported by the shell.
  }
}

function mb(bytes: number): string {
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

async function main(): Promise<void> {
  loadEnv();
  const url = process.env.DATABASE_URL?.trim();
  if (!url) {
    throw new Error('DATABASE_URL is required');
  }
  const db = new PrismaClient({ adapter: new PrismaPg({ connectionString: url }) });
  const storage = createObjectStorage(process.env);
  if ((storage as { unavailable?: boolean }).unavailable) {
    throw new Error('Object storage is not configured');
  }

  const stats = {
    images: 0,
    converted: 0,
    webpKept: 0,
    variants: 0,
    missing: 0,
    unreadable: 0,
    bytesBefore: 0,
    bytesAfter: 0,
    rowsRewritten: 0,
  };
  const processed = new Map<string, Promise<string | null>>();
  const urlMap = new Map<string, string>();

  async function variantKeys(key: string, body: Buffer, width: number): Promise<void> {
    for (const target of PUBLIC_IMAGE_VARIANT_WIDTHS) {
      if (width <= target) {
        continue;
      }
      const variantKey = imageVariantKey(key, target);
      if (!variantKey) {
        continue;
      }
      const variant = await toVariantWebp(body, target);
      if (!variant) {
        continue;
      }
      stats.variants += 1;
      stats.bytesAfter += variant.byteLength;
      if (APPLY) {
        await storage.put(variantKey, variant, 'image/webp');
      }
    }
  }

  async function processKey(key: string): Promise<string | null> {
    stats.images += 1;
    const target = key.replace(/\.(png|jpe?g)$/i, '.webp');
    const existing = await storage.get(target).catch(() => null);
    if (existing) {
      stats.webpKept += 1;
      const body = existing.body;
      stats.bytesAfter += body.byteLength;
      const size = await readImageSize(body);
      if (size) {
        await variantKeys(target, body, size.width);
      }
      return target;
    }
    const source = await storage.get(key).catch(() => null);
    if (!source) {
      stats.missing += 1;
      return null;
    }
    const normalized = await toPublicWebp(source.body);
    if (!normalized) {
      stats.unreadable += 1;
      return null;
    }
    stats.converted += 1;
    stats.bytesBefore += source.body.byteLength;
    stats.bytesAfter += normalized.body.byteLength;
    if (APPLY) {
      await storage.put(target, normalized.body, 'image/webp');
    }
    await variantKeys(target, normalized.body, normalized.width);
    return target;
  }

  async function rewrite(urlValue: string | null | undefined, key: string | null): Promise<string | null> {
    if (!urlValue || !key) {
      return null;
    }
    let pending = processed.get(key);
    if (!pending) {
      pending = processKey(key);
      processed.set(key, pending);
    }
    const newKey = await pending;
    if (!newKey || newKey === key) {
      return null;
    }
    const newUrl = urlValue.replace(/\.(png|jpe?g)$/i, '.webp');
    urlMap.set(urlValue, newUrl);
    return newUrl;
  }

  const [avatars, stores, items, classes, categories, banners, lines] = await Promise.all([
    db.user.findMany({ where: { avatarUrl: { not: null } }, select: { id: true, avatarUrl: true } }),
    db.foodStore.findMany({ select: { id: true, logoUrl: true, coverUrl: true } }),
    db.foodItem.findMany({ select: { id: true, imageUrl: true, imageUrls: true } }),
    db.rideVehicleClass.findMany({ select: { code: true, imageUrl: true } }),
    db.foodCategory.findMany({ select: { code: true, imageUrl: true } }),
    db.homeBanner.findMany({ select: { id: true, imageUrl: true } }),
    db.foodOrderLine.findMany({ where: { imageUrl: { not: null } }, select: { id: true, imageUrl: true } }),
  ]);

  for (const row of avatars) {
    await rewrite(row.avatarUrl, keyFromAvatarUrl(row.avatarUrl));
  }
  for (const row of stores) {
    await rewrite(row.logoUrl, keyFromStoreLogoUrl(row.logoUrl, 'logo'));
    await rewrite(row.coverUrl, keyFromStoreLogoUrl(row.coverUrl, 'cover'));
  }
  for (const row of items) {
    await rewrite(row.imageUrl, keyFromMenuItemImageUrl(row.imageUrl));
    const gallery = Array.isArray(row.imageUrls) ? row.imageUrls : [];
    for (const entry of gallery) {
      if (typeof entry === 'string') {
        await rewrite(entry, keyFromMenuItemImageUrl(entry));
      }
    }
  }
  for (const row of classes) {
    await rewrite(row.imageUrl, keyFromRideVehicleClassImageUrl(row.imageUrl));
  }
  for (const row of categories) {
    await rewrite(row.imageUrl, keyFromFoodCategoryImageUrl(row.imageUrl));
  }
  for (const row of banners) {
    await rewrite(row.imageUrl, keyFromHomeBannerImageUrl(row.imageUrl));
  }
  for (const row of lines) {
    await rewrite(row.imageUrl, keyFromMenuItemImageUrl(row.imageUrl));
  }

  if (APPLY) {
    for (const row of avatars) {
      const next = row.avatarUrl ? urlMap.get(row.avatarUrl) : null;
      if (next) {
        await db.user.update({ where: { id: row.id }, data: { avatarUrl: next } });
        stats.rowsRewritten += 1;
      }
    }
    for (const row of stores) {
      const logoUrl = row.logoUrl ? urlMap.get(row.logoUrl) : null;
      const coverUrl = row.coverUrl ? urlMap.get(row.coverUrl) : null;
      if (logoUrl || coverUrl) {
        await db.foodStore.update({
          where: { id: row.id },
          data: { ...(logoUrl ? { logoUrl } : {}), ...(coverUrl ? { coverUrl } : {}) },
        });
        stats.rowsRewritten += 1;
      }
    }
    for (const row of items) {
      const imageUrl = row.imageUrl ? urlMap.get(row.imageUrl) : null;
      const gallery = Array.isArray(row.imageUrls) ? row.imageUrls : [];
      const imageUrls = gallery.map((entry) =>
        typeof entry === 'string' ? (urlMap.get(entry) ?? entry) : entry,
      );
      const galleryChanged = JSON.stringify(imageUrls) !== JSON.stringify(gallery);
      if (imageUrl || galleryChanged) {
        await db.foodItem.update({
          where: { id: row.id },
          data: {
            ...(imageUrl ? { imageUrl } : {}),
            ...(galleryChanged ? { imageUrls } : {}),
          },
        });
        stats.rowsRewritten += 1;
      }
    }
    for (const row of classes) {
      const next = row.imageUrl ? urlMap.get(row.imageUrl) : null;
      if (next) {
        await db.rideVehicleClass.update({ where: { code: row.code }, data: { imageUrl: next } });
        stats.rowsRewritten += 1;
      }
    }
    for (const row of categories) {
      const next = row.imageUrl ? urlMap.get(row.imageUrl) : null;
      if (next) {
        await db.foodCategory.update({ where: { code: row.code }, data: { imageUrl: next } });
        stats.rowsRewritten += 1;
      }
    }
    for (const row of banners) {
      const next = row.imageUrl ? urlMap.get(row.imageUrl) : null;
      if (next) {
        await db.homeBanner.update({ where: { id: row.id }, data: { imageUrl: next } });
        stats.rowsRewritten += 1;
      }
    }
    for (const row of lines) {
      const next = row.imageUrl ? urlMap.get(row.imageUrl) : null;
      if (next) {
        await db.foodOrderLine.update({ where: { id: row.id }, data: { imageUrl: next } });
        stats.rowsRewritten += 1;
      }
    }
  }

  console.log(
    [
      `${APPLY ? 'APPLIED' : 'DRY RUN (set IMAGE_BACKFILL_APPLY=1 to write)'}`,
      `images=${stats.images} converted=${stats.converted} alreadyWebp=${stats.webpKept}`,
      `variants=${stats.variants} rowsRewritten=${stats.rowsRewritten}`,
      `missing=${stats.missing} unreadable=${stats.unreadable}`,
      `bytes ${mb(stats.bytesBefore)} -> ${mb(stats.bytesAfter)}`,
    ].join('\n'),
  );
  await db.$disconnect();
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
