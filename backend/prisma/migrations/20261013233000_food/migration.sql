-- CreateEnum
CREATE TYPE "FoodOrderStatus" AS ENUM ('PLACED', 'PREPARING', 'READY', 'ASSIGNED', 'CANCELLED');

-- CreateTable
CREATE TABLE "food_stores" (
    "id" UUID NOT NULL,
    "ownerId" UUID NOT NULL,
    "name" VARCHAR(120) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "food_stores_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "food_items" (
    "id" UUID NOT NULL,
    "storeId" UUID NOT NULL,
    "name" VARCHAR(160) NOT NULL,
    "priceVnd" INTEGER NOT NULL,
    "available" BOOLEAN NOT NULL DEFAULT true,

    CONSTRAINT "food_items_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "food_orders" (
    "id" UUID NOT NULL,
    "customerId" UUID NOT NULL,
    "storeId" UUID NOT NULL,
    "status" "FoodOrderStatus" NOT NULL,
    "deliveryFareVnd" INTEGER NOT NULL,
    "subtotalVnd" INTEGER NOT NULL,
    "totalVnd" INTEGER NOT NULL,
    "dropoffLat" DOUBLE PRECISION NOT NULL,
    "dropoffLng" DOUBLE PRECISION NOT NULL,
    "dropoffLabel" VARCHAR(160) NOT NULL,
    "assignedDriverId" UUID,
    "idempotencyKey" VARCHAR(200) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "food_orders_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "food_order_lines" (
    "id" UUID NOT NULL,
    "orderId" UUID NOT NULL,
    "itemId" UUID NOT NULL,
    "name" VARCHAR(160) NOT NULL,
    "unitPriceVnd" INTEGER NOT NULL,
    "quantity" INTEGER NOT NULL,

    CONSTRAINT "food_order_lines_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "food_items_storeId_idx" ON "food_items"("storeId");

-- CreateIndex
CREATE UNIQUE INDEX "food_orders_customerId_idempotencyKey_key" ON "food_orders"("customerId", "idempotencyKey");

-- CreateIndex
CREATE INDEX "food_orders_storeId_status_idx" ON "food_orders"("storeId", "status");

-- One non-terminal order per customer. Cancelled orders do not hold the slot.
CREATE UNIQUE INDEX "food_orders_one_open_per_customer" ON "food_orders"("customerId") WHERE "status" IN ('PLACED', 'PREPARING', 'READY', 'ASSIGNED');

-- CreateIndex
CREATE INDEX "food_order_lines_orderId_idx" ON "food_order_lines"("orderId");

-- AddForeignKey
ALTER TABLE "food_stores" ADD CONSTRAINT "food_stores_ownerId_fkey" FOREIGN KEY ("ownerId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "food_items" ADD CONSTRAINT "food_items_storeId_fkey" FOREIGN KEY ("storeId") REFERENCES "food_stores"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "food_orders" ADD CONSTRAINT "food_orders_customerId_fkey" FOREIGN KEY ("customerId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "food_orders" ADD CONSTRAINT "food_orders_storeId_fkey" FOREIGN KEY ("storeId") REFERENCES "food_stores"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "food_orders" ADD CONSTRAINT "food_orders_assignedDriverId_fkey" FOREIGN KEY ("assignedDriverId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "food_order_lines" ADD CONSTRAINT "food_order_lines_orderId_fkey" FOREIGN KEY ("orderId") REFERENCES "food_orders"("id") ON DELETE CASCADE ON UPDATE CASCADE;
