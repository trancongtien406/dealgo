-- AlterEnum
ALTER TYPE "LedgerAccountKind" ADD VALUE 'REVENUE';

-- AlterEnum
ALTER TYPE "LedgerJournalEvent" ADD VALUE 'DRIVER_PLATFORM_FEE_ACCRUED';

-- CreateTable
CREATE TABLE "job_earnings" (
    "id" UUID NOT NULL,
    "entityType" "LedgerEntityType" NOT NULL,
    "entityId" UUID NOT NULL,
    "driverId" UUID NOT NULL,
    "fareVnd" INTEGER NOT NULL,
    "feeBps" INTEGER NOT NULL,
    "feeVnd" INTEGER NOT NULL,
    "netVnd" INTEGER NOT NULL,
    "completedAt" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "job_earnings_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "job_earnings_driverId_completedAt_idx" ON "job_earnings"("driverId", "completedAt" DESC);

-- CreateIndex
CREATE UNIQUE INDEX "job_earnings_entityType_entityId_key" ON "job_earnings"("entityType", "entityId");

-- AddForeignKey
ALTER TABLE "job_earnings" ADD CONSTRAINT "job_earnings_driverId_fkey" FOREIGN KEY ("driverId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- A snapshot must stay internally consistent (rate 0-100 %, net = fare - fee).
ALTER TABLE "job_earnings"
  ADD CONSTRAINT "job_earnings_fee_bps_range" CHECK ("feeBps" BETWEEN 0 AND 10000),
  ADD CONSTRAINT "job_earnings_amounts_valid" CHECK ("fareVnd" >= 0 AND "feeVnd" >= 0 AND "netVnd" = "fareVnd" - "feeVnd");

-- Admin-editable settings seeded once (see PLATFORM_SETTING_SEED_DEFAULTS). Platform fees
-- start at 0 %: the real rate is set by an admin in Admin Web > Settings (OPEN-003).
INSERT INTO "platform_settings" ("id", "key", "value", "valueType", "updatedAt")
VALUES
  (gen_random_uuid(), 'RATING_WINDOW_DAYS', '7', 'number', CURRENT_TIMESTAMP),
  (gen_random_uuid(), 'PLATFORM_FEE_RIDE_PERCENT', '0', 'number', CURRENT_TIMESTAMP),
  (gen_random_uuid(), 'PLATFORM_FEE_FOOD_PERCENT', '0', 'number', CURRENT_TIMESTAMP)
ON CONFLICT ("key") DO NOTHING;
