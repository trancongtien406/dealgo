-- t82u (DEC-PROD-090): legal policy versions requiring consent + per-user consent audit.
CREATE TABLE "legal_policy_versions" (
    "id" UUID NOT NULL,
    "slug" VARCHAR(60) NOT NULL,
    "version" INTEGER NOT NULL,
    "title" VARCHAR(200) NOT NULL,
    "changelog" VARCHAR(2000) NOT NULL,
    "effectiveAt" TIMESTAMP(3),
    "audienceRoles" TEXT[],
    "requiresConsent" BOOLEAN NOT NULL DEFAULT true,
    "publishedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "publishedByUserId" UUID,
    "emailStatus" VARCHAR(16) NOT NULL DEFAULT 'NONE',
    "emailQueuedAt" TIMESTAMP(3),
    "emailRecipients" INTEGER,
    "emailSentCount" INTEGER NOT NULL DEFAULT 0,
    "emailFailedCount" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "legal_policy_versions_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "legal_policy_versions_slug_version_key" ON "legal_policy_versions"("slug", "version");
CREATE INDEX "legal_policy_versions_publishedAt_idx" ON "legal_policy_versions"("publishedAt");

CREATE TABLE "user_legal_consents" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "policyVersionId" UUID NOT NULL,
    "slug" VARCHAR(60) NOT NULL,
    "version" INTEGER NOT NULL,
    "acceptedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "ip" VARCHAR(64),
    "userAgent" VARCHAR(300),
    CONSTRAINT "user_legal_consents_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "user_legal_consents_userId_policyVersionId_key" ON "user_legal_consents"("userId", "policyVersionId");
CREATE INDEX "user_legal_consents_userId_idx" ON "user_legal_consents"("userId");
ALTER TABLE "user_legal_consents" ADD CONSTRAINT "user_legal_consents_policyVersionId_fkey" FOREIGN KEY ("policyVersionId") REFERENCES "legal_policy_versions"("id") ON DELETE CASCADE ON UPDATE CASCADE;
