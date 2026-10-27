-- Admin-managed home banners + per-day impression/click counters. Additive.
ALTER TYPE "OpsAuditEntityType" ADD VALUE 'HOME_BANNER';
ALTER TYPE "OpsAuditAction" ADD VALUE 'HOME_BANNER_CREATE';
ALTER TYPE "OpsAuditAction" ADD VALUE 'HOME_BANNER_UPDATE';
ALTER TYPE "OpsAuditAction" ADD VALUE 'HOME_BANNER_DELETE';
ALTER TYPE "OpsAuditAction" ADD VALUE 'HOME_BANNER_REORDER';

-- CreateEnum
CREATE TYPE "HomeBannerService" AS ENUM ('ALL', 'RIDE', 'FOOD');

-- CreateEnum
CREATE TYPE "HomeBannerAudience" AS ENUM ('CUSTOMER', 'DRIVER', 'MERCHANT');

-- CreateTable
CREATE TABLE "home_banners" (
    "id" UUID NOT NULL,
    "title" VARCHAR(80) NOT NULL,
    "subtitle" VARCHAR(160),
    "imageUrl" VARCHAR(300),
    "ctaUrl" VARCHAR(500),
    "audiences" "HomeBannerAudience"[],
    "service" "HomeBannerService" NOT NULL DEFAULT 'ALL',
    "regionCode" VARCHAR(8),
    "startsAt" TIMESTAMP(3),
    "endsAt" TIMESTAMP(3),
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "active" BOOLEAN NOT NULL DEFAULT false,
    "createdByUserId" UUID,
    "updatedByUserId" UUID,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "home_banners_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "home_banner_daily_stats" (
    "bannerId" UUID NOT NULL,
    "day" DATE NOT NULL,
    "impressions" INTEGER NOT NULL DEFAULT 0,
    "clicks" INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT "home_banner_daily_stats_pkey" PRIMARY KEY ("bannerId","day")
);

-- CreateIndex
CREATE INDEX "home_banners_active_sortOrder_idx" ON "home_banners"("active", "sortOrder");

-- AddForeignKey
ALTER TABLE "home_banner_daily_stats" ADD CONSTRAINT "home_banner_daily_stats_bannerId_fkey" FOREIGN KEY ("bannerId") REFERENCES "home_banners"("id") ON DELETE CASCADE ON UPDATE CASCADE;
