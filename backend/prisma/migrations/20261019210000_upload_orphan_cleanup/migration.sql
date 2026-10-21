-- DEC-PROD-022: age threshold for the scheduled cleanup of unreferenced uploads.
INSERT INTO "platform_settings" ("id", "key", "value", "valueType", "updatedAt") VALUES
  (gen_random_uuid(), 'UPLOAD_ORPHAN_MAX_AGE_HOURS', '72', 'number', CURRENT_TIMESTAMP)
ON CONFLICT ("key") DO NOTHING;
