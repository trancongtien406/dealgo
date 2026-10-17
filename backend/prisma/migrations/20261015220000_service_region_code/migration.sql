-- Ops region filters: denormalized serviceRegionCode on hot entities.
ALTER TABLE "rides" ADD COLUMN IF NOT EXISTS "serviceRegionCode" VARCHAR(8);
ALTER TABLE "food_stores" ADD COLUMN IF NOT EXISTS "serviceRegionCode" VARCHAR(8);
ALTER TABLE "food_orders" ADD COLUMN IF NOT EXISTS "serviceRegionCode" VARCHAR(8);
ALTER TABLE "driver_presence" ADD COLUMN IF NOT EXISTS "serviceRegionCode" VARCHAR(8);

CREATE INDEX IF NOT EXISTS "rides_serviceRegionCode_idx"
  ON "rides" ("serviceRegionCode");
CREATE INDEX IF NOT EXISTS "rides_serviceRegionCode_status_updatedAt_idx"
  ON "rides" ("serviceRegionCode", "status", "updatedAt");

CREATE INDEX IF NOT EXISTS "food_stores_serviceRegionCode_idx"
  ON "food_stores" ("serviceRegionCode");

CREATE INDEX IF NOT EXISTS "food_orders_serviceRegionCode_idx"
  ON "food_orders" ("serviceRegionCode");
CREATE INDEX IF NOT EXISTS "food_orders_serviceRegionCode_status_updatedAt_idx"
  ON "food_orders" ("serviceRegionCode", "status", "updatedAt");

CREATE INDEX IF NOT EXISTS "driver_presence_serviceRegionCode_idx"
  ON "driver_presence" ("serviceRegionCode");
