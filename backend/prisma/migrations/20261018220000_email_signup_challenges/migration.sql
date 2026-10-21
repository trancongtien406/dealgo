-- Pending email+password sign-ups: no user row exists until the emailed OTP is verified.
CREATE TABLE "email_signup_challenges" (
    "id" UUID NOT NULL,
    "email" TEXT NOT NULL,
    "passwordHash" TEXT,
    "displayName" TEXT NOT NULL,
    "codeHash" TEXT NOT NULL,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "attemptCount" INTEGER NOT NULL DEFAULT 0,
    "sendCount" INTEGER NOT NULL DEFAULT 1,
    "lastSentAt" TIMESTAMP(3) NOT NULL,
    "consumedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "email_signup_challenges_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "email_signup_challenges_email_createdAt_idx" ON "email_signup_challenges"("email", "createdAt");
