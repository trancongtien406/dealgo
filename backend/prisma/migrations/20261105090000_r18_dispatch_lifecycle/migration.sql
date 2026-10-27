-- R18: dispatch lifecycle (driver cancel/no-show/timeouts), customer fees, driver balance
-- adjustments, driver->customer ratings, food accept/ready timestamps. Additive only.
-- CreateEnum
CREATE TYPE "CustomerFeeKind" AS ENUM ('LATE_CANCEL', 'NO_SHOW');

-- CreateEnum
CREATE TYPE "CustomerFeeStatus" AS ENUM ('PENDING', 'COLLECTED', 'WAIVED');

-- AlterEnum
-- This migration adds more than one value to an enum.
-- With PostgreSQL versions 11 and earlier, this is not possible
-- in a single migration. This can be worked around by creating
-- multiple migrations, each migration adding only one value to
-- the enum.


ALTER TYPE "RideOfferStatus" ADD VALUE 'DECLINED';
ALTER TYPE "RideOfferStatus" ADD VALUE 'WITHDRAWN';

-- AlterTable
ALTER TABLE "food_orders" ADD COLUMN     "acceptedAt" TIMESTAMP(3),
ADD COLUMN     "readyAt" TIMESTAMP(3);

-- AlterTable
ALTER TABLE "ride_offers" ADD COLUMN     "editCount" INTEGER NOT NULL DEFAULT 0;

-- AlterTable
ALTER TABLE "rides" ADD COLUMN     "assignedAt" TIMESTAMP(3),
ADD COLUMN     "cancelReasonCode" VARCHAR(40),
ADD COLUMN     "noShow" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "priorFeesVnd" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN     "statusChangedAt" TIMESTAMP(3);

-- CreateTable
CREATE TABLE "driver_job_cancellations" (
    "id" UUID NOT NULL,
    "entityType" "LedgerEntityType" NOT NULL,
    "entityId" UUID NOT NULL,
    "driverId" UUID NOT NULL,
    "actor" "CancelActor" NOT NULL,
    "reasonCode" VARCHAR(40) NOT NULL,
    "fromStatus" VARCHAR(32) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "driver_job_cancellations_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "customer_fee_charges" (
    "id" UUID NOT NULL,
    "customerId" UUID NOT NULL,
    "rideId" UUID NOT NULL,
    "kind" "CustomerFeeKind" NOT NULL,
    "amountVnd" INTEGER NOT NULL,
    "beneficiaryDriverId" UUID,
    "status" "CustomerFeeStatus" NOT NULL DEFAULT 'PENDING',
    "collectedRideId" UUID,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "collectedAt" TIMESTAMP(3),

    CONSTRAINT "customer_fee_charges_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "driver_balance_adjustments" (
    "id" UUID NOT NULL,
    "driverId" UUID NOT NULL,
    "amountVnd" INTEGER NOT NULL,
    "kind" VARCHAR(40) NOT NULL,
    "refType" VARCHAR(20) NOT NULL,
    "refId" UUID NOT NULL,
    "occurredAt" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "driver_balance_adjustments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "customer_ratings" (
    "id" UUID NOT NULL,
    "rideId" UUID NOT NULL,
    "customerId" UUID NOT NULL,
    "driverId" UUID NOT NULL,
    "stars" SMALLINT NOT NULL,
    "tags" VARCHAR(40)[],
    "comment" VARCHAR(300),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "customer_ratings_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "driver_job_cancellations_driverId_createdAt_idx" ON "driver_job_cancellations"("driverId", "createdAt" DESC);

-- CreateIndex
CREATE INDEX "driver_job_cancellations_entityType_entityId_idx" ON "driver_job_cancellations"("entityType", "entityId");

-- CreateIndex
CREATE INDEX "customer_fee_charges_customerId_status_idx" ON "customer_fee_charges"("customerId", "status");

-- CreateIndex
CREATE UNIQUE INDEX "customer_fee_charges_rideId_kind_key" ON "customer_fee_charges"("rideId", "kind");

-- CreateIndex
CREATE INDEX "driver_balance_adjustments_driverId_occurredAt_idx" ON "driver_balance_adjustments"("driverId", "occurredAt");

-- CreateIndex
CREATE UNIQUE INDEX "driver_balance_adjustments_kind_refType_refId_driverId_key" ON "driver_balance_adjustments"("kind", "refType", "refId", "driverId");

-- CreateIndex
CREATE UNIQUE INDEX "customer_ratings_rideId_key" ON "customer_ratings"("rideId");

-- CreateIndex
CREATE INDEX "customer_ratings_customerId_idx" ON "customer_ratings"("customerId");

-- Backfill timestamps for rows already in flight so the new timeouts start from a sane point.
UPDATE "rides" SET "statusChangedAt" = "updatedAt" WHERE "statusChangedAt" IS NULL;
UPDATE "rides" SET "assignedAt" = "updatedAt"
WHERE "assignedAt" IS NULL AND "assignedDriverId" IS NOT NULL;
UPDATE "food_orders" SET "acceptedAt" = "updatedAt"
WHERE "acceptedAt" IS NULL AND "status" IN ('PREPARING', 'READY', 'ASSIGNED', 'PICKED_UP', 'DELIVERED');
UPDATE "food_orders" SET "readyAt" = "updatedAt" WHERE "readyAt" IS NULL AND "status" = 'READY';
