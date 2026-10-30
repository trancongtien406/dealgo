-- t61u (DEC-PROD-070, AGENT_PROPOSED): system auto-approval of complete KYC/KYB (default off).
ALTER TYPE "OpsAuditAction" ADD VALUE IF NOT EXISTS 'KYC_AUTO_APPROVE';

INSERT INTO "platform_settings" ("id", "key", "value", "valueType", "updatedAt")
VALUES
  (gen_random_uuid(), 'KYC_AUTO_APPROVE_DRIVER', 'false', 'json', CURRENT_TIMESTAMP),
  (gen_random_uuid(), 'KYC_AUTO_APPROVE_MERCHANT', 'false', 'json', CURRENT_TIMESTAMP)
ON CONFLICT ("key") DO NOTHING;
