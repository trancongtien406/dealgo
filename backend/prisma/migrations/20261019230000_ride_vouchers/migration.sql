-- DEC-PROD-024: ride vouchers. The discount is reserved when the customer selects an offer
-- (same transaction as the assignment) and snapshotted on the ride.
ALTER TABLE "rides" ADD COLUMN "discountVnd" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN "voucherCode" VARCHAR(40),
ADD COLUMN "voucherSponsor" "PromotionSponsor";

-- DealGo-funded ride discounts are owed to the driver (food discounts stay merchant_payable).
INSERT INTO "ledger_accounts" ("id", "code", "name", "kind", "createdAt")
VALUES
  ('a0000000-0000-4000-8000-000000000009', 'sandbox.promo.driver_payable', 'Sandbox ride voucher discount owed to driver', 'LIABILITY', CURRENT_TIMESTAMP)
ON CONFLICT ("code") DO NOTHING;
