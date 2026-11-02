-- 2026-10-31: admin toggle for the email sign-up verification code (default on = unchanged).
INSERT INTO "platform_settings" ("id", "key", "value", "valueType", "updatedAt")
VALUES (gen_random_uuid(), 'AUTH_EMAIL_VERIFICATION_REQUIRED', 'true', 'json', CURRENT_TIMESTAMP)
ON CONFLICT ("key") DO NOTHING;
