-- AlterEnum
ALTER TYPE "OpsAuditEntityType" ADD VALUE 'NOTIFICATION_CAMPAIGN';
ALTER TYPE "OpsAuditEntityType" ADD VALUE 'CMS_CONTENT';

-- AlterEnum
ALTER TYPE "OpsAuditAction" ADD VALUE 'NOTIFICATION_UPDATE';
ALTER TYPE "OpsAuditAction" ADD VALUE 'CMS_UPDATE';

-- CreateEnum
CREATE TYPE "NotificationChannel" AS ENUM ('PUSH', 'SMS', 'EMAIL', 'IN_APP');
CREATE TYPE "NotificationAudience" AS ENUM ('ALL', 'CUSTOMER', 'DRIVER', 'MERCHANT', 'STAFF');
CREATE TYPE "NotificationCampaignStatus" AS ENUM ('DRAFT', 'PENDING_APPROVAL', 'RUNNING', 'SENDING', 'SENT', 'CANCELLED');
CREATE TYPE "CmsContentKind" AS ENUM ('ARTICLE', 'BANNER', 'POLICY');
CREATE TYPE "CmsContentStatus" AS ENUM ('DRAFT', 'IN_REVIEW', 'PUBLISHED');

-- CreateTable
CREATE TABLE "notification_campaigns" (
    "id" UUID NOT NULL,
    "code" VARCHAR(24) NOT NULL,
    "title" VARCHAR(160) NOT NULL,
    "body" TEXT NOT NULL,
    "channels" "NotificationChannel"[],
    "audience" "NotificationAudience" NOT NULL,
    "audienceNote" VARCHAR(160),
    "status" "NotificationCampaignStatus" NOT NULL DEFAULT 'DRAFT',
    "isAutomatic" BOOLEAN NOT NULL DEFAULT false,
    "scheduledAt" TIMESTAMP(3),
    "reachedCount" INTEGER,
    "rejectionReason" VARCHAR(500),
    "submittedAt" TIMESTAMP(3),
    "approvedAt" TIMESTAMP(3),
    "sentAt" TIMESTAMP(3),
    "cancelledAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "createdByUserId" UUID,
    "updatedByUserId" UUID,
    "approvedByUserId" UUID,

    CONSTRAINT "notification_campaigns_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "cms_contents" (
    "id" UUID NOT NULL,
    "kind" "CmsContentKind" NOT NULL,
    "title" VARCHAR(200) NOT NULL,
    "body" TEXT NOT NULL,
    "status" "CmsContentStatus" NOT NULL DEFAULT 'DRAFT',
    "publishedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "createdByUserId" UUID,
    "updatedByUserId" UUID,

    CONSTRAINT "cms_contents_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "notification_campaigns_code_key" ON "notification_campaigns"("code");
CREATE INDEX "notification_campaigns_status_createdAt_idx" ON "notification_campaigns"("status", "createdAt");
CREATE INDEX "notification_campaigns_createdAt_idx" ON "notification_campaigns"("createdAt");
CREATE INDEX "cms_contents_kind_status_createdAt_idx" ON "cms_contents"("kind", "status", "createdAt");
