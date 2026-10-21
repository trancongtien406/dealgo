-- Sandbox ledger accounts for DRIVER_PLATFORM_FEE_ACCRUED (separate migration: the REVENUE
-- enum value must be committed before use). Idempotent insert.
INSERT INTO "ledger_accounts" ("id", "code", "name", "kind", "createdAt")
VALUES
  ('a0000000-0000-4000-8000-000000000007', 'sandbox.fee.driver_receivable', 'Sandbox platform fee owed by driver (COD)', 'ASSET', CURRENT_TIMESTAMP),
  ('a0000000-0000-4000-8000-000000000008', 'sandbox.fee.platform_revenue', 'Sandbox platform fee revenue', 'REVENUE', CURRENT_TIMESTAMP)
ON CONFLICT ("code") DO NOTHING;
