-- DEC-PROD-034: snapshot the store pickup point on the order at placement.
-- AlterTable
ALTER TABLE "food_orders" ADD COLUMN     "pickupLabel" VARCHAR(200),
ADD COLUMN     "pickupLat" DOUBLE PRECISION,
ADD COLUMN     "pickupLng" DOUBLE PRECISION;

-- Backfill existing orders once from the store's current point (best available value).
UPDATE "food_orders" AS o
SET "pickupLat" = s."lat",
    "pickupLng" = s."lng",
    "pickupLabel" = LEFT(s."addressLabel", 200)
FROM "food_stores" AS s
WHERE o."storeId" = s."id"
  AND s."lat" IS NOT NULL
  AND s."lng" IS NOT NULL;
