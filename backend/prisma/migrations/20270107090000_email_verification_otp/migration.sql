-- Profile email verification uses a 6-digit code: count wrong guesses and pace resends.
ALTER TABLE "email_verifications"
  ADD COLUMN "attemptCount" INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN "lastSentAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;

CREATE INDEX "email_verifications_userId_createdAt_idx" ON "email_verifications"("userId", "createdAt");
DROP INDEX IF EXISTS "email_verifications_userId_idx";
