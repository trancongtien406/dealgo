-- Customer history lists filter by customer and order by newest first.
CREATE INDEX "rides_customer_createdAt_idx" ON "rides"("customerId", "createdAt" DESC);
CREATE INDEX "food_orders_customer_createdAt_idx" ON "food_orders"("customerId", "createdAt" DESC);
