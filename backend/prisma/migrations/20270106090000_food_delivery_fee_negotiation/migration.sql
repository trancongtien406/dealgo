-- Food delivery fee negotiation: the fee is a suggestion; the customer offers, drivers accept or counter.
CREATE TYPE "FoodDeliveryOfferStatus" AS ENUM ('PENDING', 'SELECTED', 'LOST', 'WITHDRAWN');

ALTER TABLE "food_orders"
  ADD COLUMN "suggestedDeliveryFareVnd" INTEGER,
  ADD COLUMN "deliveryFareAgreedAt" TIMESTAMP(3),
  ADD COLUMN "deliveryFareRaiseCount" INTEGER NOT NULL DEFAULT 0;

-- Existing orders: the fee they were placed with was the suggestion; assigned ones count as agreed.
UPDATE "food_orders" SET "suggestedDeliveryFareVnd" = "deliveryFareVnd";
UPDATE "food_orders" SET "deliveryFareAgreedAt" = "updatedAt" WHERE "assignedDriverId" IS NOT NULL;

CREATE TABLE "food_delivery_offers" (
    "id" UUID NOT NULL,
    "orderId" UUID NOT NULL,
    "driverId" UUID NOT NULL,
    "amountVnd" INTEGER NOT NULL,
    "status" "FoodDeliveryOfferStatus" NOT NULL DEFAULT 'PENDING',
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "editCount" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "food_delivery_offers_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "food_delivery_offers_orderId_driverId_key" ON "food_delivery_offers"("orderId", "driverId");
CREATE INDEX "food_delivery_offers_orderId_status_idx" ON "food_delivery_offers"("orderId", "status");
CREATE INDEX "food_delivery_offers_driverId_status_idx" ON "food_delivery_offers"("driverId", "status");
ALTER TABLE "food_delivery_offers" ADD CONSTRAINT "food_delivery_offers_orderId_fkey" FOREIGN KEY ("orderId") REFERENCES "food_orders"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "food_delivery_offers" ADD CONSTRAINT "food_delivery_offers_driverId_fkey" FOREIGN KEY ("driverId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- Admin-editable negotiation bounds (insert-if-absent).
INSERT INTO "platform_settings" ("id", "key", "value", "valueType", "updatedAt") VALUES
  (gen_random_uuid(), 'FOOD_FARE_FLOOR_PERCENT_OF_SUGGESTED', '70', 'number', CURRENT_TIMESTAMP),
  (gen_random_uuid(), 'FOOD_COUNTER_MAX_PERCENT_OF_OFFER', '150', 'number', CURRENT_TIMESTAMP),
  (gen_random_uuid(), 'FOOD_FARE_STEP_VND', '1000', 'number', CURRENT_TIMESTAMP),
  (gen_random_uuid(), 'FOOD_MAX_OFFER_EDITS_PER_DRIVER', '2', 'number', CURRENT_TIMESTAMP),
  (gen_random_uuid(), 'FOOD_MAX_FARE_RAISES_PER_ORDER', '3', 'number', CURRENT_TIMESTAMP),
  (gen_random_uuid(), 'FOOD_OFFER_TTL_SECONDS', '120', 'number', CURRENT_TIMESTAMP),
  (gen_random_uuid(), 'FOOD_DELIVERY_FEE_MODE', 'NEGOTIATE', 'string', CURRENT_TIMESTAMP)
ON CONFLICT ("key") DO NOTHING;
