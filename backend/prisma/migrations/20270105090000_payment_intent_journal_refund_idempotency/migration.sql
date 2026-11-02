-- MONEY-002: capture journals are keyed per payment intent (one PSP_PAYMENT_CAPTURED per intent).
ALTER TYPE "LedgerEntityType" ADD VALUE IF NOT EXISTS 'PAYMENT_INTENT';

-- ADM-003: ops refunds carry a client idempotency key.
ALTER TABLE "payment_refunds" ADD COLUMN "idempotencyKey" VARCHAR(64);
CREATE UNIQUE INDEX "payment_refunds_idempotencyKey_key" ON "payment_refunds"("idempotencyKey");
