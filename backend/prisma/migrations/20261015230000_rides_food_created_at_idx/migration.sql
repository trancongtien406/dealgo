-- Speeds ops overview hourly trend: WHERE "createdAt" >= $1 GROUP BY hour
CREATE INDEX IF NOT EXISTS "rides_createdAt_idx" ON "rides" ("createdAt");
CREATE INDEX IF NOT EXISTS "food_orders_createdAt_idx" ON "food_orders" ("createdAt");
