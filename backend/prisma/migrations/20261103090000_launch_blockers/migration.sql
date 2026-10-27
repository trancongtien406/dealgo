-- Launch blockers (DEC-PROD-052..056): app review login + chat review audit, public pages, worker heartbeat, settings.
-- CreateEnum
CREATE TYPE "PublicPageStatus" AS ENUM ('DRAFT', 'PUBLISHED');

-- AlterEnum

ALTER TYPE "OpsAuditEntityType" ADD VALUE 'CHAT_THREAD';
ALTER TYPE "OpsAuditEntityType" ADD VALUE 'PUBLIC_PAGE';

-- AlterEnum

ALTER TYPE "OpsAuditAction" ADD VALUE 'APP_REVIEW_LOGIN';
ALTER TYPE "OpsAuditAction" ADD VALUE 'CHAT_REVIEW';
ALTER TYPE "OpsAuditAction" ADD VALUE 'PUBLIC_PAGE_PUBLISH';

-- CreateTable
CREATE TABLE "public_pages" (
    "id" UUID NOT NULL,
    "slug" VARCHAR(60) NOT NULL,
    "locale" VARCHAR(5) NOT NULL,
    "title" VARCHAR(200) NOT NULL,
    "summary" VARCHAR(500),
    "body" TEXT NOT NULL,
    "status" "PublicPageStatus" NOT NULL DEFAULT 'DRAFT',
    "version" INTEGER NOT NULL DEFAULT 0,
    "effectiveAt" TIMESTAMP(3),
    "publishedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "updatedByUserId" UUID,

    CONSTRAINT "public_pages_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "public_page_revisions" (
    "id" UUID NOT NULL,
    "pageId" UUID NOT NULL,
    "version" INTEGER NOT NULL,
    "title" VARCHAR(200) NOT NULL,
    "summary" VARCHAR(500),
    "body" TEXT NOT NULL,
    "effectiveAt" TIMESTAMP(3),
    "publishedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "publishedByUserId" UUID,

    CONSTRAINT "public_page_revisions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "worker_heartbeats" (
    "name" VARCHAR(60) NOT NULL,
    "instance" VARCHAR(120) NOT NULL,
    "startedAt" TIMESTAMP(3) NOT NULL,
    "beatAt" TIMESTAMP(3) NOT NULL,
    "meta" JSONB NOT NULL DEFAULT '{}',

    CONSTRAINT "worker_heartbeats_pkey" PRIMARY KEY ("name")
);

-- CreateIndex
CREATE UNIQUE INDEX "public_pages_slug_locale_key" ON "public_pages"("slug", "locale");

-- CreateIndex
CREATE UNIQUE INDEX "public_page_revisions_pageId_version_key" ON "public_page_revisions"("pageId", "version");

-- AddForeignKey
ALTER TABLE "public_page_revisions" ADD CONSTRAINT "public_page_revisions_pageId_fkey" FOREIGN KEY ("pageId") REFERENCES "public_pages"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- Seeded platform settings (PLATFORM_SETTING_SEED_DEFAULTS).
INSERT INTO "platform_settings" ("id", "key", "value", "valueType", "updatedAt")
VALUES
  (gen_random_uuid(), 'CHAT_RETENTION_DAYS', '90', 'number', CURRENT_TIMESTAMP),
  (gen_random_uuid(), 'APP_REVIEW_LOGIN_ENABLED', 'false', 'json', CURRENT_TIMESTAMP),
  (gen_random_uuid(), 'APP_REVIEW_PHONE', '', 'string', CURRENT_TIMESTAMP),
  (gen_random_uuid(), 'APP_REVIEW_EMAIL', '', 'string', CURRENT_TIMESTAMP)
ON CONFLICT ("key") DO NOTHING;
