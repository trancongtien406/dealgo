-- Ops promotion campaigns persisted in Postgres (previously an in-process Map).
-- Sample campaigns live in prisma/seed.ts only; no rows are inserted here.
-- CreateEnum
CREATE TYPE "PromotionStatus" AS ENUM ('ACTIVE', 'SCHEDULED', 'PAUSED', 'ENDED', 'DRAFT', 'CANCELLED');

-- CreateEnum
CREATE TYPE "PromotionServiceType" AS ENUM ('ALL', 'RIDE', 'FOOD');

-- CreateEnum
CREATE TYPE "PromotionDiscountType" AS ENUM ('FIXED_AMOUNT', 'PERCENTAGE', 'DELIVERY_DISCOUNT');

-- CreateEnum
CREATE TYPE "PromotionAudience" AS ENUM ('ALL', 'CUSTOMER', 'DRIVER', 'MERCHANT');

-- CreateEnum
CREATE TYPE "PromotionSponsor" AS ENUM ('PLATFORM', 'MERCHANT', 'SHARED');

-- CreateTable
CREATE TABLE "promotions" (
    "id" UUID NOT NULL,
    "code" VARCHAR(40) NOT NULL,
    "name" VARCHAR(160) NOT NULL,
    "description" TEXT NOT NULL,
    "serviceType" "PromotionServiceType" NOT NULL,
    "discountType" "PromotionDiscountType" NOT NULL,
    "discountValue" INTEGER NOT NULL,
    "maxDiscountAmount" INTEGER,
    "minOrderAmount" INTEGER NOT NULL DEFAULT 0,
    "totalBudget" INTEGER NOT NULL,
    "usedBudget" INTEGER NOT NULL DEFAULT 0,
    "usageLimit" INTEGER NOT NULL,
    "usedCount" INTEGER NOT NULL DEFAULT 0,
    "userLimit" INTEGER NOT NULL DEFAULT 1,
    "targetAudience" "PromotionAudience" NOT NULL DEFAULT 'ALL',
    "status" "PromotionStatus" NOT NULL DEFAULT 'ACTIVE',
    "startDate" TIMESTAMP(3) NOT NULL,
    "endDate" TIMESTAMP(3) NOT NULL,
    "sponsor" "PromotionSponsor" NOT NULL DEFAULT 'PLATFORM',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "promotions_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "promotions_code_key" ON "promotions"("code");

-- CreateIndex
CREATE INDEX "promotions_status_createdAt_idx" ON "promotions"("status", "createdAt");

-- CreateIndex
CREATE INDEX "promotions_createdAt_idx" ON "promotions"("createdAt");
