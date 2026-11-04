-- Driver prepayments are a liability of DealGo, never revenue.
INSERT INTO "ledger_accounts" ("id", "code", "name", "kind", "createdAt")
VALUES
  ('a0000000-0000-4000-8000-000000000016', 'driver.credit_liability', 'Driver prepaid credit (liability)', 'LIABILITY', CURRENT_TIMESTAMP)
ON CONFLICT ("code") DO NOTHING;

-- payOS order codes are unique per merchant account. Reserve 1e9..2.1e9 for driver
-- top-ups so later payment links for customer jobs cannot collide with them.
ALTER SEQUENCE "driver_top_ups_orderCode_seq" RESTART WITH 1000000000;
