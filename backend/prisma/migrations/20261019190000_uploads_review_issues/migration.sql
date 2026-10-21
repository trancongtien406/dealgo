-- DEC-PROD-020: stored uploads for KYC/KYB documents and ticket attachments,
-- per-section review issues on partner applications, admin upload limits.
ALTER TABLE "partner_applications" ADD COLUMN "reviewIssues" JSONB NOT NULL DEFAULT '[]';
ALTER TABLE "support_ticket_messages" ADD COLUMN "attachments" JSONB NOT NULL DEFAULT '[]';

INSERT INTO "platform_settings" ("id", "key", "value", "valueType", "updatedAt") VALUES
  (gen_random_uuid(), 'UPLOAD_MAX_FILE_KB', '4096', 'number', CURRENT_TIMESTAMP),
  (gen_random_uuid(), 'UPLOAD_ALLOWED_TYPES', '["image/jpeg","image/png","image/webp","application/pdf"]', 'json', CURRENT_TIMESTAMP)
ON CONFLICT ("key") DO NOTHING;
