-- AlterEnum RideStatus
ALTER TYPE "RideStatus" ADD VALUE 'DRIVER_EN_ROUTE';
ALTER TYPE "RideStatus" ADD VALUE 'DRIVER_ARRIVED';
ALTER TYPE "RideStatus" ADD VALUE 'IN_TRIP';
ALTER TYPE "RideStatus" ADD VALUE 'COMPLETED';

-- AlterEnum FoodOrderStatus
ALTER TYPE "FoodOrderStatus" ADD VALUE 'PICKED_UP';
ALTER TYPE "FoodOrderStatus" ADD VALUE 'DELIVERED';
ALTER TYPE "FoodOrderStatus" ADD VALUE 'FAILED';

-- Include in-progress delivery in the one-open-per-customer slot.
DROP INDEX IF EXISTS "food_orders_one_open_per_customer";
CREATE UNIQUE INDEX "food_orders_one_open_per_customer" ON "food_orders"("customerId")
WHERE "status" IN ('PLACED', 'PREPARING', 'READY', 'ASSIGNED', 'PICKED_UP');
