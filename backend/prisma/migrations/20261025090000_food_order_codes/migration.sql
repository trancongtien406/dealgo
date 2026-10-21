-- DEC-PROD-036: server-issued food delivery + merchant handover codes.
-- CreateEnum
CREATE TYPE "FoodOrderCodeKind" AS ENUM ('DELIVERY', 'HANDOVER');

-- CreateTable
CREATE TABLE "food_order_codes" (
    "orderId" UUID NOT NULL,
    "kind" "FoodOrderCodeKind" NOT NULL,
    "code" VARCHAR(8) NOT NULL,
    "failedAttempts" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "verifiedAt" TIMESTAMP(3),

    CONSTRAINT "food_order_codes_pkey" PRIMARY KEY ("orderId","kind")
);

-- AddForeignKey
ALTER TABLE "food_order_codes" ADD CONSTRAINT "food_order_codes_orderId_fkey" FOREIGN KEY ("orderId") REFERENCES "food_orders"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- Delivery proof is on by default; the merchant↔driver handover code is opt-in.
INSERT INTO "platform_settings" ("id", "key", "value", "valueType", "updatedAt")
VALUES
  (gen_random_uuid(), 'FOOD_DELIVERY_CODE_REQUIRED', 'true', 'json', CURRENT_TIMESTAMP),
  (gen_random_uuid(), 'FOOD_DELIVERY_CODE_MAX_ATTEMPTS', '5', 'number', CURRENT_TIMESTAMP),
  (gen_random_uuid(), 'FOOD_HANDOVER_CODE_REQUIRED', 'false', 'json', CURRENT_TIMESTAMP)
ON CONFLICT ("key") DO NOTHING;
