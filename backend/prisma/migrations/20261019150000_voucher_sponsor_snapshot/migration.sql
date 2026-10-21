-- DEC-PROD-015: snapshot who funds a voucher discount onto the order.
-- AlterTable
ALTER TABLE "food_orders" ADD COLUMN     "voucherSponsor" "PromotionSponsor";

-- Backfill orders that already used a voucher from their campaign's current sponsor.
UPDATE "food_orders" AS o
SET "voucherSponsor" = p."sponsor"
FROM "promotion_redemptions" AS r
JOIN "promotions" AS p ON p."id" = r."promotionId"
WHERE r."entityType" = 'FOOD_ORDER'
  AND r."entityId" = o."id"
  AND o."voucherSponsor" IS NULL;

-- DealGo's share of SHARED-sponsor discounts. 100 keeps DEC-PROD-009 behaviour until an admin
-- agrees a split in Admin Web > Settings.
INSERT INTO "platform_settings" ("id", "key", "value", "valueType", "updatedAt")
VALUES (gen_random_uuid(), 'VOUCHER_SHARED_PLATFORM_PERCENT', '100', 'number', CURRENT_TIMESTAMP)
ON CONFLICT ("key") DO NOTHING;
