-- DEC-PROD-019: store averages are shown only after this many ratings (rater privacy).
INSERT INTO "platform_settings" ("id", "key", "value", "valueType", "updatedAt") VALUES
  (gen_random_uuid(), 'RATING_STORE_MIN_COUNT', '3', 'number', CURRENT_TIMESTAMP)
ON CONFLICT ("key") DO NOTHING;
