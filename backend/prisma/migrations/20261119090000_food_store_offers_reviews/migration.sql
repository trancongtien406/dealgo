-- Store offers: a merchant-created promotion scoped to one food store.
ALTER TABLE "promotions" ADD COLUMN "storeId" UUID;
ALTER TABLE "promotions" ADD CONSTRAINT "promotions_storeId_fkey" FOREIGN KEY ("storeId") REFERENCES "food_stores"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
CREATE INDEX "promotions_storeId_status_idx" ON "promotions"("storeId", "status");

-- Store reviews: merchant reply and ops moderation.
ALTER TABLE "service_ratings" ADD COLUMN "merchantReply" VARCHAR(500);
ALTER TABLE "service_ratings" ADD COLUMN "repliedAt" TIMESTAMP(3);
ALTER TABLE "service_ratings" ADD COLUMN "hiddenAt" TIMESTAMP(3);
ALTER TABLE "service_ratings" ADD COLUMN "hiddenReason" VARCHAR(500);

-- Ops moderation of store offers and reviews is audited.
ALTER TYPE "OpsAuditEntityType" ADD VALUE IF NOT EXISTS 'PROMOTION';
ALTER TYPE "OpsAuditEntityType" ADD VALUE IF NOT EXISTS 'SERVICE_RATING';
ALTER TYPE "OpsAuditAction" ADD VALUE IF NOT EXISTS 'PROMOTION_STATUS_UPDATE';
ALTER TYPE "OpsAuditAction" ADD VALUE IF NOT EXISTS 'REVIEW_HIDE';
ALTER TYPE "OpsAuditAction" ADD VALUE IF NOT EXISTS 'REVIEW_UNHIDE';
