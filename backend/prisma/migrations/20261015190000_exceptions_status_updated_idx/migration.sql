-- Help ops exceptions: per-status ORDER BY "updatedAt" DESC LIMIT N (index stop early).
CREATE INDEX IF NOT EXISTS "rides_status_updatedAt_desc_idx"
  ON "rides" ("status", "updatedAt" DESC);

CREATE INDEX IF NOT EXISTS "food_orders_status_updatedAt_desc_idx"
  ON "food_orders" ("status", "updatedAt" DESC);
