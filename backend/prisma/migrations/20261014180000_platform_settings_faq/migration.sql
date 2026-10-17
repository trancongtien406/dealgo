-- AlterEnum
ALTER TYPE "OpsAuditEntityType" ADD VALUE 'PLATFORM_SETTING';

-- AlterEnum
ALTER TYPE "OpsAuditEntityType" ADD VALUE 'OPS_FAQ';

-- AlterEnum
ALTER TYPE "OpsAuditAction" ADD VALUE 'SETTINGS_UPDATE';

-- AlterEnum
ALTER TYPE "OpsAuditAction" ADD VALUE 'FAQ_UPDATE';

-- CreateEnum
CREATE TYPE "PlatformSettingValueType" AS ENUM ('string', 'number', 'json');

-- CreateEnum
CREATE TYPE "OpsFaqStatus" AS ENUM ('DRAFT', 'PUBLISHED', 'ARCHIVED');

-- CreateEnum
CREATE TYPE "OpsFaqCategory" AS ENUM ('POLICY', 'OPS', 'PRODUCT', 'TECH');

-- CreateTable
CREATE TABLE "platform_settings" (
    "id" UUID NOT NULL,
    "key" VARCHAR(80) NOT NULL,
    "value" TEXT NOT NULL,
    "valueType" "PlatformSettingValueType" NOT NULL,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "updatedByUserId" UUID,

    CONSTRAINT "platform_settings_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ops_faq_entries" (
    "id" UUID NOT NULL,
    "openId" VARCHAR(16),
    "question" VARCHAR(500) NOT NULL,
    "suggestedAnswer" TEXT NOT NULL,
    "status" "OpsFaqStatus" NOT NULL DEFAULT 'DRAFT',
    "category" "OpsFaqCategory" NOT NULL,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "createdByUserId" UUID,
    "updatedByUserId" UUID,

    CONSTRAINT "ops_faq_entries_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "platform_settings_key_key" ON "platform_settings"("key");

-- CreateIndex
CREATE INDEX "ops_faq_entries_status_sortOrder_idx" ON "ops_faq_entries"("status", "sortOrder");

-- CreateIndex
CREATE INDEX "ops_faq_entries_openId_idx" ON "ops_faq_entries"("openId");

-- AddForeignKey
ALTER TABLE "platform_settings" ADD CONSTRAINT "platform_settings_updatedByUserId_fkey" FOREIGN KEY ("updatedByUserId") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ops_faq_entries" ADD CONSTRAINT "ops_faq_entries_createdByUserId_fkey" FOREIGN KEY ("createdByUserId") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ops_faq_entries" ADD CONSTRAINT "ops_faq_entries_updatedByUserId_fkey" FOREIGN KEY ("updatedByUserId") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
