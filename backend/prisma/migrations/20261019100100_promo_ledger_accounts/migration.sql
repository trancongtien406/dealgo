-- Sandbox ledger accounts for DealGo-funded voucher discounts (PROMOTION_DISCOUNT_FUNDED):
-- debit platform expense, credit the amount owed to the merchant. Idempotent insert.
INSERT INTO "ledger_accounts" ("id", "code", "name", "kind", "createdAt")
VALUES
  ('a0000000-0000-4000-8000-000000000005', 'sandbox.promo.discount_expense', 'Sandbox DealGo-funded voucher discount expense', 'EXPENSE', CURRENT_TIMESTAMP),
  ('a0000000-0000-4000-8000-000000000006', 'sandbox.promo.merchant_payable', 'Sandbox voucher discount owed to merchant', 'LIABILITY', CURRENT_TIMESTAMP)
ON CONFLICT ("code") DO NOTHING;
