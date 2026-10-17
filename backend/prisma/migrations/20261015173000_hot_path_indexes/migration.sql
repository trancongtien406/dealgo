-- Hot-path list indexes (open/ready/ops timelines). Idempotent for re-runs.
CREATE INDEX IF NOT EXISTS "rides_status_createdAt_idx" ON "rides"("status", "createdAt");
CREATE INDEX IF NOT EXISTS "food_orders_status_createdAt_idx" ON "food_orders"("status", "createdAt");
CREATE INDEX IF NOT EXISTS "food_stores_lat_lng_idx" ON "food_stores"("lat", "lng");
