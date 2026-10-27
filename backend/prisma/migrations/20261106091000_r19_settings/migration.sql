-- R19 DRAFT defaults (docs DEC-R19). Insert-if-absent; admins change them on the Settings page.
-- Gap 8: RIDE_NEGOTIATION_MAX_ROUNDS really capped live offers per ride; copy its value to the
-- correctly named key (empty = unlimited -> 0). The old key stays readable for rollback.
INSERT INTO "platform_settings" ("id", "key", "value", "valueType", "updatedAt")
SELECT gen_random_uuid(), 'RIDE_MAX_LIVE_OFFERS_PER_RIDE',
       CASE WHEN "value" ~ '^[0-9]+$' THEN "value" ELSE '0' END, 'number', CURRENT_TIMESTAMP
FROM "platform_settings" WHERE "key" = 'RIDE_NEGOTIATION_MAX_ROUNDS'
ON CONFLICT ("key") DO NOTHING;
INSERT INTO "platform_settings" ("id", "key", "value", "valueType", "updatedAt")
VALUES (gen_random_uuid(), 'RIDE_MAX_LIVE_OFFERS_PER_RIDE', '0', 'number', CURRENT_TIMESTAMP)
ON CONFLICT ("key") DO NOTHING;
INSERT INTO "platform_settings" ("id", "key", "value", "valueType", "updatedAt")
VALUES (gen_random_uuid(), 'RIDE_MAX_FARE_RAISES_PER_RIDE', '3', 'number', CURRENT_TIMESTAMP)
ON CONFLICT ("key") DO NOTHING;
INSERT INTO "platform_settings" ("id", "key", "value", "valueType", "updatedAt")
VALUES (gen_random_uuid(), 'CUSTOMER_CANCEL_LIMIT_COUNT', '3', 'number', CURRENT_TIMESTAMP)
ON CONFLICT ("key") DO NOTHING;
INSERT INTO "platform_settings" ("id", "key", "value", "valueType", "updatedAt")
VALUES (gen_random_uuid(), 'CUSTOMER_CANCEL_LIMIT_WINDOW_HOURS', '24', 'number', CURRENT_TIMESTAMP)
ON CONFLICT ("key") DO NOTHING;
INSERT INTO "platform_settings" ("id", "key", "value", "valueType", "updatedAt")
VALUES (gen_random_uuid(), 'CUSTOMER_CANCEL_COOLDOWN_MINUTES', '30', 'number', CURRENT_TIMESTAMP)
ON CONFLICT ("key") DO NOTHING;
INSERT INTO "platform_settings" ("id", "key", "value", "valueType", "updatedAt")
VALUES (gen_random_uuid(), 'DRIVER_CANCEL_RATE_WINDOW_DAYS', '7', 'number', CURRENT_TIMESTAMP)
ON CONFLICT ("key") DO NOTHING;
INSERT INTO "platform_settings" ("id", "key", "value", "valueType", "updatedAt")
VALUES (gen_random_uuid(), 'DRIVER_CANCEL_RATE_WARN_PERCENT', '20', 'number', CURRENT_TIMESTAMP)
ON CONFLICT ("key") DO NOTHING;
INSERT INTO "platform_settings" ("id", "key", "value", "valueType", "updatedAt")
VALUES (gen_random_uuid(), 'RIDE_REQUEST_PUSH_ENABLED', 'true', 'json', CURRENT_TIMESTAMP)
ON CONFLICT ("key") DO NOTHING;
INSERT INTO "platform_settings" ("id", "key", "value", "valueType", "updatedAt")
VALUES (gen_random_uuid(), 'RIDE_REQUEST_PUSH_MAX_DRIVERS', '30', 'number', CURRENT_TIMESTAMP)
ON CONFLICT ("key") DO NOTHING;
INSERT INTO "platform_settings" ("id", "key", "value", "valueType", "updatedAt")
VALUES (gen_random_uuid(), 'FOOD_FAIL_MIN_WAIT_MINUTES', '10', 'number', CURRENT_TIMESTAMP)
ON CONFLICT ("key") DO NOTHING;
INSERT INTO "platform_settings" ("id", "key", "value", "valueType", "updatedAt")
VALUES (gen_random_uuid(), 'FOOD_MERCHANT_COMMISSION_PERCENT', '20', 'number', CURRENT_TIMESTAMP)
ON CONFLICT ("key") DO NOTHING;
INSERT INTO "platform_settings" ("id", "key", "value", "valueType", "updatedAt")
VALUES (gen_random_uuid(), 'FOOD_ORDER_CHANGE_RESPONSE_MINUTES', '5', 'number', CURRENT_TIMESTAMP)
ON CONFLICT ("key") DO NOTHING;
INSERT INTO "platform_settings" ("id", "key", "value", "valueType", "updatedAt")
VALUES (gen_random_uuid(), 'RIDE_REPOST_RAISE_HINT_PERCENT', '10', 'number', CURRENT_TIMESTAMP)
ON CONFLICT ("key") DO NOTHING;
-- Gap 15: sandbox ledger accounts for MERCHANT_COMMISSION_ACCRUED (idempotent).
INSERT INTO "ledger_accounts" ("id", "code", "name", "kind", "createdAt")
VALUES
  ('a0000000-0000-4000-8000-000000000010', 'sandbox.commission.merchant_receivable', 'Sandbox merchant commission owed to DealGo', 'ASSET', CURRENT_TIMESTAMP),
  ('a0000000-0000-4000-8000-000000000011', 'sandbox.commission.revenue', 'Sandbox merchant commission revenue', 'REVENUE', CURRENT_TIMESTAMP)
ON CONFLICT ("code") DO NOTHING;
