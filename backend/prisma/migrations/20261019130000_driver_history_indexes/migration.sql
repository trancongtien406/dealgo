-- CreateIndex
CREATE INDEX "food_orders_driver_history_idx" ON "food_orders"("assignedDriverId", "updatedAt" DESC);

-- CreateIndex
CREATE INDEX "rides_driver_history_idx" ON "rides"("assignedDriverId", "updatedAt" DESC);

