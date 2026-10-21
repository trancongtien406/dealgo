-- CreateEnum
CREATE TYPE "AccountDeletionMethod" AS ENUM ('PHONE_OTP', 'PASSWORD');

-- CreateEnum
CREATE TYPE "AccountDeletionStatus" AS ENUM ('PENDING', 'SCHEDULED', 'CANCELLED', 'PURGED');

-- AlterEnum
-- This migration adds more than one value to an enum.
-- With PostgreSQL versions 11 and earlier, this is not possible
-- in a single migration. This can be worked around by creating
-- multiple migrations, each migration adding only one value to
-- the enum.


ALTER TYPE "OpsAuditAction" ADD VALUE 'OPS_SUPER_ADMIN_GRANT';
ALTER TYPE "OpsAuditAction" ADD VALUE 'OPS_SUPER_ADMIN_REVOKE';
ALTER TYPE "OpsAuditAction" ADD VALUE 'ACCOUNT_DELETION_CANCEL';
ALTER TYPE "OpsAuditAction" ADD VALUE 'DRIVER_FEE_SETTLE';

-- AlterEnum
ALTER TYPE "OpsAuditEntityType" ADD VALUE 'USER';

-- AlterTable
ALTER TABLE "users" ADD COLUMN     "deletedAt" TIMESTAMP(3),
ADD COLUMN     "purgeAfter" TIMESTAMP(3),
ADD COLUMN     "purgedAt" TIMESTAMP(3);

-- CreateTable
CREATE TABLE "account_deletion_requests" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "method" "AccountDeletionMethod" NOT NULL,
    "status" "AccountDeletionStatus" NOT NULL DEFAULT 'PENDING',
    "codeHash" TEXT,
    "attemptCount" INTEGER NOT NULL DEFAULT 0,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "confirmedAt" TIMESTAMP(3),
    "purgeAfter" TIMESTAMP(3),
    "cancelledAt" TIMESTAMP(3),
    "cancelledByUserId" UUID,
    "purgedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "account_deletion_requests_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "driver_fee_settlements" (
    "id" UUID NOT NULL,
    "driverId" UUID NOT NULL,
    "amountVnd" INTEGER NOT NULL,
    "settledThrough" TIMESTAMP(3) NOT NULL,
    "actorUserId" UUID NOT NULL,
    "reason" VARCHAR(500) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "driver_fee_settlements_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "account_deletion_requests_userId_createdAt_idx" ON "account_deletion_requests"("userId", "createdAt" DESC);

-- CreateIndex
CREATE INDEX "account_deletion_requests_status_purgeAfter_idx" ON "account_deletion_requests"("status", "purgeAfter");

-- CreateIndex
CREATE INDEX "driver_fee_settlements_driverId_settledThrough_idx" ON "driver_fee_settlements"("driverId", "settledThrough" DESC);

-- AddForeignKey
ALTER TABLE "account_deletion_requests" ADD CONSTRAINT "account_deletion_requests_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "driver_fee_settlements" ADD CONSTRAINT "driver_fee_settlements_driverId_fkey" FOREIGN KEY ("driverId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "driver_fee_settlements" ADD CONSTRAINT "driver_fee_settlements_actorUserId_fkey" FOREIGN KEY ("actorUserId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- S027 grace period before the purge worker anonymizes a soft-deleted account.
INSERT INTO "platform_settings" ("id", "key", "value", "valueType", "updatedAt")
VALUES (gen_random_uuid(), 'ACCOUNT_DELETION_GRACE_DAYS', '7', 'number', CURRENT_TIMESTAMP)
ON CONFLICT ("key") DO NOTHING;
