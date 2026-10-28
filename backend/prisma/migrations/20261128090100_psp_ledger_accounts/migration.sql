-- Ledger accounts for PSP_PAYMENT_CAPTURED / PSP_REFUND_RECORDED. Idempotent insert.
INSERT INTO "ledger_accounts" ("id", "code", "name", "kind", "createdAt")
VALUES
  ('a0000000-0000-4000-8000-000000000012', 'psp.clearing_receivable', 'Online payments held by PSP (clearing receivable)', 'ASSET', CURRENT_TIMESTAMP),
  ('a0000000-0000-4000-8000-000000000013', 'psp.customer_prepaid', 'Customer prepayment for online-paid jobs', 'LIABILITY', CURRENT_TIMESTAMP)
ON CONFLICT ("code") DO NOTHING;
