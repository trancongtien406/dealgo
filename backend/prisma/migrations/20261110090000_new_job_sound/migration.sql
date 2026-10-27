-- r26: spoken "DealGo, có cuốc mới" alert sound for new ride / food job / merchant order pushes.
-- Per-user opt-out (default on) ...
ALTER TABLE "user_notification_preferences" ADD COLUMN "newJobSound" BOOLEAN NOT NULL DEFAULT true;

-- ... and the platform-wide admin switch (catalog NEW_JOB_CUSTOM_SOUND_ENABLED, default on).
INSERT INTO "platform_settings" ("id", "key", "value", "valueType", "updatedAt")
VALUES (gen_random_uuid(), 'NEW_JOB_CUSTOM_SOUND_ENABLED', 'true', 'json', CURRENT_TIMESTAMP)
ON CONFLICT ("key") DO NOTHING;
