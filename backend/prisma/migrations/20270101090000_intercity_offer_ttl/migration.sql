-- t73u (owner pt73u): driver offers live 20 s, editable in Admin › Cài đặt (10–120 s).
INSERT INTO "platform_settings" ("id", "key", "value", "valueType", "updatedAt")
VALUES (gen_random_uuid(), 'RIDE_OFFER_TTL_SECONDS', '20', 'number', CURRENT_TIMESTAMP)
ON CONFLICT ("key") DO UPDATE SET "value" = '20', "updatedAt" = CURRENT_TIMESTAMP;

-- t73u DEC-RIDE-CROSS-REGION: intercity (Liên tỉnh) settings. Ships OFF; ops enable it in Admin.
INSERT INTO "platform_settings" ("id", "key", "value", "valueType", "updatedAt")
VALUES (gen_random_uuid(), 'RIDE_INTERCITY_ENABLED', 'false', 'json', CURRENT_TIMESTAMP)
ON CONFLICT ("key") DO NOTHING;
INSERT INTO "platform_settings" ("id", "key", "value", "valueType", "updatedAt")
VALUES (gen_random_uuid(), 'RIDE_INTERCITY_VEHICLE_CLASSES', '[]', 'json', CURRENT_TIMESTAMP)
ON CONFLICT ("key") DO NOTHING;
INSERT INTO "platform_settings" ("id", "key", "value", "valueType", "updatedAt")
VALUES (gen_random_uuid(), 'RIDE_INTERCITY_PRICING', '{}', 'json', CURRENT_TIMESTAMP)
ON CONFLICT ("key") DO NOTHING;
INSERT INTO "platform_settings" ("id", "key", "value", "valueType", "updatedAt")
VALUES (gen_random_uuid(), 'RIDE_INTERCITY_MAX_KM', '0', 'number', CURRENT_TIMESTAMP)
ON CONFLICT ("key") DO NOTHING;
