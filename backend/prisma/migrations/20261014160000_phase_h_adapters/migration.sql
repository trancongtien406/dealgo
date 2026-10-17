-- AlterEnum PaymentMethod
ALTER TYPE "PaymentMethod" ADD VALUE 'VNPAY';
ALTER TYPE "PaymentMethod" ADD VALUE 'MOMO';

-- AlterEnum PaymentIntentStatus
ALTER TYPE "PaymentIntentStatus" ADD VALUE 'CREATED';
ALTER TYPE "PaymentIntentStatus" ADD VALUE 'PENDING_REDIRECT';
ALTER TYPE "PaymentIntentStatus" ADD VALUE 'CAPTURED_STUB';

-- AlterTable payment_intents
ALTER TABLE "payment_intents" ADD COLUMN "providerRef" VARCHAR(120);
ALTER TABLE "payment_intents" ADD COLUMN "paymentUrl" VARCHAR(2000);

CREATE INDEX "payment_intents_providerRef_idx" ON "payment_intents"("providerRef");

-- CreateTable payment_webhook_events
CREATE TABLE "payment_webhook_events" (
    "id" UUID NOT NULL,
    "provider" VARCHAR(32) NOT NULL,
    "providerEventId" VARCHAR(160) NOT NULL,
    "paymentIntentId" UUID,
    "status" VARCHAR(40) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "payment_webhook_events_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "payment_webhook_events_provider_providerEventId_key" ON "payment_webhook_events"("provider", "providerEventId");
CREATE INDEX "payment_webhook_events_createdAt_idx" ON "payment_webhook_events"("createdAt");

-- CreateTable voice_sessions
CREATE TABLE "voice_sessions" (
    "id" UUID NOT NULL,
    "aggregateType" VARCHAR(32) NOT NULL,
    "aggregateId" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "roomName" VARCHAR(160) NOT NULL,
    "provider" VARCHAR(32) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "expiresAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "voice_sessions_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "voice_sessions_aggregateType_aggregateId_idx" ON "voice_sessions"("aggregateType", "aggregateId");
CREATE INDEX "voice_sessions_userId_createdAt_idx" ON "voice_sessions"("userId", "createdAt");
