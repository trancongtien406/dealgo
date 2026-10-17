-- CreateEnum
CREATE TYPE "PaymentEntityType" AS ENUM ('RIDE', 'FOOD_ORDER');

-- CreateEnum
CREATE TYPE "PaymentMethod" AS ENUM ('COD');

-- CreateEnum
CREATE TYPE "PaymentIntentStatus" AS ENUM ('SANDBOX_RECORDED');

-- CreateTable
CREATE TABLE "payment_intents" (
    "id" UUID NOT NULL,
    "entityType" "PaymentEntityType" NOT NULL,
    "entityId" UUID NOT NULL,
    "method" "PaymentMethod" NOT NULL,
    "status" "PaymentIntentStatus" NOT NULL DEFAULT 'SANDBOX_RECORDED',
    "amountVnd" INTEGER NOT NULL,
    "currency" VARCHAR(3) NOT NULL DEFAULT 'VND',
    "provider" VARCHAR(32) NOT NULL DEFAULT 'sandbox',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "payment_intents_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "payment_intents_entityType_entityId_idx" ON "payment_intents"("entityType", "entityId");

-- CreateIndex
CREATE INDEX "payment_intents_createdAt_idx" ON "payment_intents"("createdAt");

-- CreateIndex
CREATE UNIQUE INDEX "payment_intents_entityType_entityId_method_key" ON "payment_intents"("entityType", "entityId", "method");
