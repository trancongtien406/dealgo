-- R19 logic gaps (docs DEC-R19): food fail reasons, cash model, order changes, negotiation rounds, re-post.
-- CreateEnum
CREATE TYPE "FoodOrderChangeStatus" AS ENUM ('PENDING', 'ACCEPTED', 'REJECTED', 'EXPIRED');

-- AlterEnum
ALTER TYPE "LedgerJournalEvent" ADD VALUE 'MERCHANT_COMMISSION_ACCRUED';

-- AlterTable
ALTER TABLE "food_orders" ADD COLUMN     "failNote" VARCHAR(300),
ADD COLUMN     "failReasonCode" VARCHAR(32),
ADD COLUMN     "failedAt" TIMESTAMP(3),
ADD COLUMN     "merchantCashVnd" INTEGER,
ADD COLUMN     "merchantCommissionBps" INTEGER,
ADD COLUMN     "merchantCommissionVnd" INTEGER,
ADD COLUMN     "pickedUpAt" TIMESTAMP(3);

-- AlterTable
ALTER TABLE "rides" ADD COLUMN     "fareRaiseCount" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN     "repostOfRideId" UUID,
ALTER COLUMN "vehicleClassCode" DROP DEFAULT;

-- CreateTable
CREATE TABLE "food_order_changes" (
    "id" UUID NOT NULL,
    "orderId" UUID NOT NULL,
    "status" "FoodOrderChangeStatus" NOT NULL DEFAULT 'PENDING',
    "reasonCode" VARCHAR(32) NOT NULL,
    "note" VARCHAR(200),
    "lines" JSONB NOT NULL,
    "oldSubtotalVnd" INTEGER NOT NULL,
    "newSubtotalVnd" INTEGER NOT NULL,
    "newDiscountVnd" INTEGER NOT NULL,
    "newTotalVnd" INTEGER NOT NULL,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "respondedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "food_order_changes_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "merchant_settlements" (
    "id" UUID NOT NULL,
    "storeId" UUID NOT NULL,
    "periodStart" DATE NOT NULL,
    "periodEnd" DATE NOT NULL,
    "orderCount" INTEGER NOT NULL,
    "grossVnd" INTEGER NOT NULL,
    "merchantFundedVnd" INTEGER NOT NULL,
    "commissionVnd" INTEGER NOT NULL,
    "netVnd" INTEGER NOT NULL,
    "actorUserId" UUID NOT NULL,
    "note" VARCHAR(500),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "merchant_settlements_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "food_order_changes_orderId_createdAt_idx" ON "food_order_changes"("orderId", "createdAt" DESC);

-- CreateIndex
CREATE INDEX "food_order_changes_status_expiresAt_idx" ON "food_order_changes"("status", "expiresAt");

-- CreateIndex
CREATE INDEX "merchant_settlements_storeId_periodEnd_idx" ON "merchant_settlements"("storeId", "periodEnd" DESC);

-- CreateIndex
CREATE UNIQUE INDEX "merchant_settlements_storeId_periodStart_periodEnd_key" ON "merchant_settlements"("storeId", "periodStart", "periodEnd");

-- AddForeignKey
ALTER TABLE "food_order_changes" ADD CONSTRAINT "food_order_changes_orderId_fkey" FOREIGN KEY ("orderId") REFERENCES "food_orders"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- Backfill: orders already picked up get a pickup time so the failed-delivery wait can be checked.
UPDATE "food_orders" SET "pickedUpAt" = "updatedAt" WHERE "status" = 'PICKED_UP' AND "pickedUpAt" IS NULL;
