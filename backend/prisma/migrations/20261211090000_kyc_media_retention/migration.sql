-- t54u (DEC-PROD-070, AGENT_PROPOSED): KYC liveness-clip retention purge.
ALTER TYPE "OpsAuditAction" ADD VALUE IF NOT EXISTS 'KYC_MEDIA_PURGE';

INSERT INTO "platform_settings" ("id", "key", "value", "valueType", "updatedAt")
VALUES (gen_random_uuid(), 'KYC_VIDEO_RETENTION_DAYS', '90', 'number', CURRENT_TIMESTAMP)
ON CONFLICT ("key") DO NOTHING;
