/**
 * Removes everything `seed-app-review.ts` created (and whatever the review account did since):
 * its rides, offers, food orders, store + menu + images, audit rows, then the user itself
 * (grants, applications, presence, sessions, passkeys and credentials cascade), the store's
 * vouchers (+ redemptions), reviews, hours (cascade) and cover, and the seeded demo customers
 * (appreview-customer-N@…). Turns the review login off. Production needs
 * SEED_ALLOW_PRODUCTION=true for the run.
 */
import { createObjectStorage } from '../src/platform/storage/storage.module.js';
import { keyFromMenuItemImageUrl } from '../src/modules/catalog/menu-item-image.service.js';
import { keyFromStoreLogoUrl } from '../src/modules/catalog/store-logo.service.js';
import { assertSeedAllowed } from './seed-guard.js';
import {
  APP_REVIEW_CUSTOMER_EMAIL_DOMAIN,
  APP_REVIEW_CUSTOMER_EMAIL_PREFIX,
  APP_REVIEW_DEMO_EMAIL,
  APP_REVIEW_SEED_TAG,
  appReviewDb,
} from './seed-app-review.js';

async function main(): Promise<void> {
  assertSeedAllowed(process.env);
  const db = appReviewDb();
  const storage = createObjectStorage(process.env);
  try {
    const user = await db.user.findUnique({ where: { email: APP_REVIEW_DEMO_EMAIL } });
    const removed: Record<string, number> = {};
    const objectKeys: string[] = [];
    const customers = await db.user.findMany({
      where: { email: { startsWith: APP_REVIEW_CUSTOMER_EMAIL_PREFIX, endsWith: APP_REVIEW_CUSTOMER_EMAIL_DOMAIN } },
      select: { id: true },
    });
    const customerIds = customers.map((c) => c.id);
    if (user) {
      const uid = user.id;
      const stores = await db.foodStore.findMany({ where: { ownerId: uid }, include: { items: true } });
      const storeIds = stores.map((s) => s.id);
      for (const s of stores) {
        const logo = keyFromStoreLogoUrl(s.logoUrl);
        if (logo) objectKeys.push(logo);
        const cover = keyFromStoreLogoUrl(s.coverUrl, 'cover');
        if (cover) objectKeys.push(cover);
        for (const it of s.items) {
          for (const url of [it.imageUrl, ...(Array.isArray(it.imageUrls) ? (it.imageUrls as unknown[]) : [])]) {
            const key = typeof url === 'string' ? keyFromMenuItemImageUrl(url) : null;
            if (key && !objectKeys.includes(key)) objectKeys.push(key);
          }
        }
      }
      await db.$transaction(async (tx) => {
        const rides = await tx.ride.findMany({ where: { OR: [{ customerId: uid }, { assignedDriverId: uid }] }, select: { id: true } });
        const rideIds = rides.map((r) => r.id);
        removed.rideSelections = (await tx.rideSelection.deleteMany({ where: { OR: [{ customerId: uid }, { rideId: { in: rideIds } }] } })).count;
        removed.rideOffers = (await tx.rideOffer.deleteMany({ where: { driverId: uid } })).count;
        removed.chatMessages = (await tx.chatMessage.deleteMany({ where: { senderUserId: uid } })).count;
        removed.jobEarnings = (await tx.jobEarning.deleteMany({ where: { driverId: uid } })).count;
        removed.driverFeeSettlements = (await tx.driverFeeSettlement.deleteMany({ where: { OR: [{ driverId: uid }, { actorUserId: uid }] } })).count;
        removed.rides = (await tx.ride.deleteMany({ where: { id: { in: rideIds } } })).count;
        removed.foodOrders = (
          await tx.foodOrder.deleteMany({ where: { OR: [{ customerId: uid }, { assignedDriverId: uid }, { storeId: { in: storeIds } }] } })
        ).count;
        removed.serviceRatings = (await tx.serviceRating.deleteMany({ where: { OR: [{ storeId: { in: storeIds } }, { raterId: { in: customerIds } }] } })).count;
        const promos = await tx.promotion.findMany({ where: { storeId: { in: storeIds } }, select: { id: true } });
        const promoIds = promos.map((p) => p.id);
        removed.promotionRedemptions = (await tx.promotionRedemption.deleteMany({ where: { promotionId: { in: promoIds } } })).count;
        removed.promotions = (await tx.promotion.deleteMany({ where: { id: { in: promoIds } } })).count;
        removed.auditLogs = (await tx.opsAuditLog.deleteMany({ where: { actorUserId: uid } })).count;
        removed.stores = (await tx.foodStore.deleteMany({ where: { id: { in: storeIds } } })).count;
        removed.users = (await tx.user.deleteMany({ where: { id: uid } })).count;
      });
      for (const key of objectKeys) await storage.delete(key).catch(() => undefined);
      removed.objects = objectKeys.length;
    }
    if (customerIds.length) {
      await db.$transaction(async (tx) => {
        removed.customerOrders = (await tx.foodOrder.deleteMany({ where: { customerId: { in: customerIds } } })).count;
        removed.customerRatings = (await tx.serviceRating.deleteMany({ where: { raterId: { in: customerIds } } })).count;
        removed.customers = (await tx.user.deleteMany({ where: { id: { in: customerIds } } })).count;
      });
    }
    const email = await db.platformSetting.findUnique({ where: { key: 'APP_REVIEW_EMAIL' } });
    if (email?.value.trim().toLowerCase() === APP_REVIEW_DEMO_EMAIL) {
      await db.platformSetting.update({ where: { key: 'APP_REVIEW_EMAIL' }, data: { value: '' } });
      await db.platformSetting.updateMany({ where: { key: 'APP_REVIEW_LOGIN_ENABLED' }, data: { value: 'false' } });
      removed.reviewLoginDisabled = 1;
    }
    console.log(JSON.stringify({ cleanup: APP_REVIEW_SEED_TAG, found: Boolean(user), ...removed }, null, 2));
  } finally {
    await db.$disconnect();
  }
}

main().catch((error: unknown) => {
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
});
