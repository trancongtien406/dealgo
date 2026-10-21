-- CreateEnum
CREATE TYPE "StoreAcceptMode" AS ENUM ('MANUAL', 'AUTO');

-- AlterTable
ALTER TABLE "food_orders" ADD COLUMN     "prepMinutes" INTEGER;

-- AlterTable
ALTER TABLE "food_stores" ADD COLUMN     "acceptMode" "StoreAcceptMode" NOT NULL DEFAULT 'MANUAL',
ADD COLUMN     "busyExtraMinutes" INTEGER NOT NULL DEFAULT 15,
ADD COLUMN     "defaultPrepMinutes" INTEGER NOT NULL DEFAULT 15,
ADD COLUMN     "maxActiveOrders" INTEGER;

-- DEC-PROD-028 bounds (mirrored by the DTO).
ALTER TABLE "food_stores" ADD CONSTRAINT "food_stores_accept_bounds" CHECK (
  ("maxActiveOrders" IS NULL OR "maxActiveOrders" BETWEEN 1 AND 50)
  AND "defaultPrepMinutes" BETWEEN 5 AND 90
  AND "busyExtraMinutes" BETWEEN 0 AND 120
);
