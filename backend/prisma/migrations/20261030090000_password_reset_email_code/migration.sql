-- DEC-PROD-045: forgot password moves from an emailed link token to a 6-digit code challenge.
-- Outstanding link tokens are retired: the new confirm endpoint only accepts codes.
UPDATE "password_resets" SET "consumedAt" = CURRENT_TIMESTAMP WHERE "consumedAt" IS NULL;

ALTER TABLE "password_resets" ALTER COLUMN "userId" DROP NOT NULL;
ALTER TABLE "password_resets" ADD COLUMN "email" TEXT NOT NULL DEFAULT '';
ALTER TABLE "password_resets" ALTER COLUMN "email" DROP DEFAULT;
ALTER TABLE "password_resets" ADD COLUMN "attemptCount" INTEGER NOT NULL DEFAULT 0;
ALTER TABLE "password_resets" ADD COLUMN "sendCount" INTEGER NOT NULL DEFAULT 1;
ALTER TABLE "password_resets" ADD COLUMN "lastSentAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;

UPDATE "password_resets" r SET "email" = COALESCE(u."email", '') FROM "users" u WHERE u."id" = r."userId";

CREATE INDEX "password_resets_email_createdAt_idx" ON "password_resets"("email", "createdAt");

-- Admin-tunable limits (platform settings, insert-if-absent).
INSERT INTO "platform_settings" ("id", "key", "value", "valueType", "updatedAt")
VALUES
  (gen_random_uuid(), 'AUTH_PASSWORD_RESET_CODE_TTL_MINUTES', '10', 'number', CURRENT_TIMESTAMP),
  (gen_random_uuid(), 'AUTH_PASSWORD_RESET_MAX_ATTEMPTS', '5', 'number', CURRENT_TIMESTAMP),
  (gen_random_uuid(), 'AUTH_PASSWORD_RESET_MAX_PER_HOUR', '5', 'number', CURRENT_TIMESTAMP)
ON CONFLICT ("key") DO NOTHING;
