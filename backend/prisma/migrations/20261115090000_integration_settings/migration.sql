-- Admin-managed integration credentials (email provider, map keys), secrets encrypted at rest.
CREATE TYPE "IntegrationKind" AS ENUM ('EMAIL', 'MAPS');
CREATE TYPE "EmailSuppressionReason" AS ENUM ('BOUNCE', 'COMPLAINT');

ALTER TYPE "OpsAuditEntityType" ADD VALUE 'INTEGRATION_SETTING';
ALTER TYPE "OpsAuditAction" ADD VALUE 'INTEGRATION_SETTING_UPDATE';
ALTER TYPE "OpsAuditAction" ADD VALUE 'INTEGRATION_SETTING_TEST';

CREATE TABLE "integration_settings" (
    "id" UUID NOT NULL,
    "kind" "IntegrationKind" NOT NULL,
    "config" JSONB NOT NULL DEFAULT '{}',
    "secretsCiphertext" TEXT,
    "testedFingerprint" VARCHAR(64),
    "testedAt" TIMESTAMP(3),
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "updatedByUserId" UUID,

    CONSTRAINT "integration_settings_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "integration_settings_kind_key" ON "integration_settings"("kind");

ALTER TABLE "integration_settings" ADD CONSTRAINT "integration_settings_updatedByUserId_fkey" FOREIGN KEY ("updatedByUserId") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- SES bounce / complaint suppression list (SNS webhook).
CREATE TABLE "email_suppressions" (
    "email" VARCHAR(320) NOT NULL,
    "reason" "EmailSuppressionReason" NOT NULL,
    "detail" VARCHAR(500),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "email_suppressions_pkey" PRIMARY KEY ("email")
);
