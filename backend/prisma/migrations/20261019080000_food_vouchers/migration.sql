-- Food checkout vouchers: discount snapshot on the order, redemption ledger per order,
-- and an optional store address shown to drivers on ready jobs. Additive only.
-- CreateEnum
CREATE TYPE "PromotionRedemptionEntity" AS ENUM ('FOOD_ORDER', 'RIDE');

-- AlterTable
ALTER TABLE "food_orders" ADD COLUMN     "discountVnd" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN     "voucherCode" VARCHAR(40);

-- AlterTable
ALTER TABLE "food_stores" ADD COLUMN     "addressLabel" VARCHAR(200);

-- CreateTable
CREATE TABLE "promotion_redemptions" (
    "id" UUID NOT NULL,
    "promotionId" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "entityType" "PromotionRedemptionEntity" NOT NULL,
    "entityId" UUID NOT NULL,
    "discountVnd" INTEGER NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "promotion_redemptions_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "promotion_redemptions_promotionId_userId_idx" ON "promotion_redemptions"("promotionId", "userId");

-- CreateIndex
CREATE UNIQUE INDEX "promotion_redemptions_entityType_entityId_key" ON "promotion_redemptions"("entityType", "entityId");

-- AddForeignKey
ALTER TABLE "promotion_redemptions" ADD CONSTRAINT "promotion_redemptions_promotionId_fkey" FOREIGN KEY ("promotionId") REFERENCES "promotions"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

