-- Driver prepaid credit (DEC-PROD-093): fees are offset from topped-up credit; topping up stays
-- disabled until Ops turns it on after the payOS/VNPAY merchant account is live.
INSERT INTO "platform_settings" ("id", "key", "value", "valueType", "updatedAt")
VALUES
  (gen_random_uuid(), 'DRIVER_TOP_UP_ENABLED', 'false', 'json', CURRENT_TIMESTAMP),
  (gen_random_uuid(), 'DRIVER_TOP_UP_MIN_VND', '10000', 'number', CURRENT_TIMESTAMP),
  (gen_random_uuid(), 'DRIVER_TOP_UP_MAX_VND', '2000000', 'number', CURRENT_TIMESTAMP),
  (gen_random_uuid(), 'DRIVER_TOP_UP_DAILY_LIMIT_VND', '5000000', 'number', CURRENT_TIMESTAMP),
  (gen_random_uuid(), 'DRIVER_CREDIT_MAX_VND', '5000000', 'number', CURRENT_TIMESTAMP),
  (gen_random_uuid(), 'DRIVER_TOP_UP_EXPIRE_MINUTES', '15', 'number', CURRENT_TIMESTAMP)
ON CONFLICT ("key") DO NOTHING;
