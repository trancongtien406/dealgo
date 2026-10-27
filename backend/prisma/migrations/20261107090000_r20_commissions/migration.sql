-- R20 (DEC-R20): split the single driver platform fee into per-service commissions.
--   PLATFORM_FEE_RIDE_PERCENT -> RIDE_COMMISSION_BIKE_PERCENT and RIDE_COMMISSION_CAR_PERCENT
--   PLATFORM_FEE_FOOD_PERCENT -> FOOD_DRIVER_COMMISSION_PERCENT
-- Existing values are copied so nobody's earnings change on deploy. Insert-if-absent; the old rows
-- stay in the table (no longer read) so a rollback keeps the admin's last values.
INSERT INTO "platform_settings" ("id", "key", "value", "valueType", "updatedAt")
SELECT gen_random_uuid(), 'RIDE_COMMISSION_BIKE_PERCENT', "value", 'number', CURRENT_TIMESTAMP
FROM "platform_settings" WHERE "key" = 'PLATFORM_FEE_RIDE_PERCENT'
ON CONFLICT ("key") DO NOTHING;
INSERT INTO "platform_settings" ("id", "key", "value", "valueType", "updatedAt")
SELECT gen_random_uuid(), 'RIDE_COMMISSION_CAR_PERCENT', "value", 'number', CURRENT_TIMESTAMP
FROM "platform_settings" WHERE "key" = 'PLATFORM_FEE_RIDE_PERCENT'
ON CONFLICT ("key") DO NOTHING;
INSERT INTO "platform_settings" ("id", "key", "value", "valueType", "updatedAt")
SELECT gen_random_uuid(), 'FOOD_DRIVER_COMMISSION_PERCENT', "value", 'number', CURRENT_TIMESTAMP
FROM "platform_settings" WHERE "key" = 'PLATFORM_FEE_FOOD_PERCENT'
ON CONFLICT ("key") DO NOTHING;

-- Fresh databases (no old rows): seed defaults (0 % until an admin decides, OPEN-003).
INSERT INTO "platform_settings" ("id", "key", "value", "valueType", "updatedAt")
VALUES (gen_random_uuid(), 'RIDE_COMMISSION_BIKE_PERCENT', '0', 'number', CURRENT_TIMESTAMP)
ON CONFLICT ("key") DO NOTHING;
INSERT INTO "platform_settings" ("id", "key", "value", "valueType", "updatedAt")
VALUES (gen_random_uuid(), 'RIDE_COMMISSION_CAR_PERCENT', '0', 'number', CURRENT_TIMESTAMP)
ON CONFLICT ("key") DO NOTHING;
INSERT INTO "platform_settings" ("id", "key", "value", "valueType", "updatedAt")
VALUES (gen_random_uuid(), 'FOOD_DRIVER_COMMISSION_PERCENT', '0', 'number', CURRENT_TIMESTAMP)
ON CONFLICT ("key") DO NOTHING;
INSERT INTO "platform_settings" ("id", "key", "value", "valueType", "updatedAt")
VALUES (gen_random_uuid(), 'MERCHANT_SETTLEMENT_CYCLE_DAYS', '7', 'number', CURRENT_TIMESTAMP)
ON CONFLICT ("key") DO NOTHING;
