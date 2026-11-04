-- CreateEnum
CREATE TYPE "DriverTopUpStatus" AS ENUM ('PENDING', 'PAID', 'EXPIRED', 'CANCELLED', 'REFUND_PENDING', 'REFUNDED', 'FAILED');

-- AlterEnum
-- This migration adds more than one value to an enum.
-- With PostgreSQL versions 11 and earlier, this is not possible
-- in a single migration. This can be worked around by creating
-- multiple migrations, each migration adding only one value to
-- the enum.


ALTER TYPE "LedgerEntityType" ADD VALUE 'DRIVER_TOP_UP';
ALTER TYPE "LedgerEntityType" ADD VALUE 'DRIVER_FEE_SETTLEMENT';

-- AlterEnum
-- This migration adds more than one value to an enum.
-- With PostgreSQL versions 11 and earlier, this is not possible
-- in a single migration. This can be worked around by creating
-- multiple migrations, each migration adding only one value to
-- the enum.


ALTER TYPE "LedgerJournalEvent" ADD VALUE 'DRIVER_CREDIT_TOP_UP_CAPTURED';
ALTER TYPE "LedgerJournalEvent" ADD VALUE 'DRIVER_CREDIT_APPLIED_TO_FEE';
ALTER TYPE "LedgerJournalEvent" ADD VALUE 'DRIVER_CREDIT_REFUNDED';

-- AlterTable
ALTER TABLE "driver_fee_settlements" ADD COLUMN     "creditAppliedVnd" INTEGER NOT NULL DEFAULT 0;

-- CreateTable
CREATE TABLE "driver_top_ups" (
    "id" UUID NOT NULL,
    "driverId" UUID NOT NULL,
    "orderCode" SERIAL NOT NULL,
    "provider" VARCHAR(32) NOT NULL DEFAULT 'payos',
    "paymentLinkId" VARCHAR(120),
    "amountVnd" INTEGER NOT NULL,
    "remainingVnd" INTEGER NOT NULL DEFAULT 0,
    "consumedVnd" INTEGER NOT NULL DEFAULT 0,
    "refundedVnd" INTEGER NOT NULL DEFAULT 0,
    "status" "DriverTopUpStatus" NOT NULL DEFAULT 'PENDING',
    "checkoutUrl" VARCHAR(2000),
    "qrCode" VARCHAR(2000),
    "providerTransId" VARCHAR(120),
    "idempotencyKey" VARCHAR(120),
    "failureReason" VARCHAR(255),
    "expiresAt" TIMESTAMP(3),
    "paidAt" TIMESTAMP(3),
    "refundedAt" TIMESTAMP(3),
    "refundBankRef" VARCHAR(120),
    "refundReason" VARCHAR(500),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "driver_top_ups_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "driver_credit_applications" (
    "id" UUID NOT NULL,
    "topUpId" UUID NOT NULL,
    "driverId" UUID NOT NULL,
    "amountVnd" INTEGER NOT NULL,
    "refType" VARCHAR(32) NOT NULL,
    "refId" UUID NOT NULL,
    "occurredAt" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "driver_credit_applications_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "driver_top_ups_orderCode_key" ON "driver_top_ups"("orderCode");

-- CreateIndex
CREATE INDEX "driver_top_ups_driverId_status_idx" ON "driver_top_ups"("driverId", "status");

-- CreateIndex
CREATE INDEX "driver_top_ups_status_updatedAt_idx" ON "driver_top_ups"("status", "updatedAt");

-- CreateIndex
CREATE UNIQUE INDEX "driver_top_ups_driverId_idempotencyKey_key" ON "driver_top_ups"("driverId", "idempotencyKey");

-- CreateIndex
CREATE INDEX "driver_credit_applications_driverId_occurredAt_idx" ON "driver_credit_applications"("driverId", "occurredAt");

-- CreateIndex
CREATE UNIQUE INDEX "driver_credit_applications_refType_refId_topUpId_key" ON "driver_credit_applications"("refType", "refId", "topUpId");

-- AddForeignKey
ALTER TABLE "driver_top_ups" ADD CONSTRAINT "driver_top_ups_driverId_fkey" FOREIGN KEY ("driverId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "driver_credit_applications" ADD CONSTRAINT "driver_credit_applications_topUpId_fkey" FOREIGN KEY ("topUpId") REFERENCES "driver_top_ups"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
