-- 2026-10-29: customer<->driver code confirmation off by default (admin toggles stay).
-- Data-only: adds the ride toggle (off) and switches the food delivery code off.
INSERT INTO "platform_settings" ("id", "key", "value", "valueType", "updatedAt")
VALUES (gen_random_uuid(), 'RIDE_PICKUP_CODE_REQUIRED', 'false', 'json', CURRENT_TIMESTAMP)
ON CONFLICT ("key") DO NOTHING;

UPDATE "platform_settings" SET "value" = 'false', "updatedAt" = CURRENT_TIMESTAMP
WHERE "key" = 'FOOD_DELIVERY_CODE_REQUIRED';
