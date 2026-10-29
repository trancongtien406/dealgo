-- Repeat "Cuốc xe mới" push while a request stays open (admin-tunable, data only).
INSERT INTO "platform_settings" ("id", "key", "value", "valueType", "updatedAt")
VALUES (gen_random_uuid(), 'RIDE_REQUEST_REPUSH_INTERVAL_SEC', '30', 'number', CURRENT_TIMESTAMP)
ON CONFLICT ("key") DO NOTHING;
INSERT INTO "platform_settings" ("id", "key", "value", "valueType", "updatedAt")
VALUES (gen_random_uuid(), 'RIDE_REQUEST_REPUSH_MAX', '3', 'number', CURRENT_TIMESTAMP)
ON CONFLICT ("key") DO NOTHING;
