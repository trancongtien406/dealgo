-- Online vs cash settlement, multiple refunds, reconciliation (additive, idempotent).
ALTER TYPE "LedgerEntityType" ADD VALUE IF NOT EXISTS 'PAYMENT_REFUND';
ALTER TYPE "LedgerJournalEvent" ADD VALUE IF NOT EXISTS 'PSP_PREPAID_APPLIED';
ALTER TYPE "LedgerJournalEvent" ADD VALUE IF NOT EXISTS 'PSP_REFUND_AFTER_SETTLEMENT';

ALTER TABLE "payment_intents"
  ADD COLUMN IF NOT EXISTS "settledAt" TIMESTAMP(3),
  ADD COLUMN IF NOT EXISTS "lastReconciledAt" TIMESTAMP(3),
  ADD COLUMN IF NOT EXISTS "reconcileAttempts" INTEGER NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS "payment_refunds" (
  "id" UUID NOT NULL,
  "paymentIntentId" UUID NOT NULL,
  "amountVnd" INTEGER NOT NULL,
  "status" VARCHAR(16) NOT NULL,
  "requestId" VARCHAR(64) NOT NULL,
  "providerRefundRef" VARCHAR(120),
  "reason" VARCHAR(200) NOT NULL,
  "actorUserId" UUID NOT NULL,
  "afterSettlement" BOOLEAN NOT NULL DEFAULT false,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "payment_refunds_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX IF NOT EXISTS "payment_refunds_requestId_key" ON "payment_refunds"("requestId");
CREATE INDEX IF NOT EXISTS "payment_refunds_paymentIntentId_idx" ON "payment_refunds"("paymentIntentId");
DO $$ BEGIN
  ALTER TABLE "payment_refunds" ADD CONSTRAINT "payment_refunds_paymentIntentId_fkey"
    FOREIGN KEY ("paymentIntentId") REFERENCES "payment_intents"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

INSERT INTO "ledger_accounts" ("id", "code", "name", "kind", "createdAt")
VALUES
  ('a0000000-0000-4000-8000-000000000014', 'psp.job_payout_payable', 'Online-paid job payout owed to drivers', 'LIABILITY', CURRENT_TIMESTAMP),
  ('a0000000-0000-4000-8000-000000000015', 'psp.refund_expense', 'Online refunds absorbed after settlement', 'EXPENSE', CURRENT_TIMESTAMP)
ON CONFLICT ("code") DO NOTHING;

-- Retire the legacy PAYMENT_METHODS_ENABLED flag: PAYMENT_METHOD_REGISTRY is the single source.
DELETE FROM "platform_settings" WHERE "key" = 'PAYMENT_METHODS_ENABLED';
