-- DEC-PROD-021: merchant decline reason shown to the customer.
ALTER TABLE "food_orders" ADD COLUMN "cancelReasonCode" VARCHAR(32);
ALTER TABLE "food_orders" ADD COLUMN "cancelNote" VARCHAR(200);

-- DEC-PROD-021: FAQ audience (INTERNAL OPEN drafts vs in-app help).
CREATE TYPE "FaqAudience" AS ENUM ('INTERNAL', 'CUSTOMER', 'DRIVER', 'MERCHANT');
ALTER TABLE "ops_faq_entries" ADD COLUMN "audience" "FaqAudience" NOT NULL DEFAULT 'INTERNAL';
CREATE INDEX "ops_faq_entries_audience_status_sortOrder_idx" ON "ops_faq_entries"("audience", "status", "sortOrder");

-- DEC-PROD-021: trip share links (token hash only).
CREATE TABLE "ride_share_links" (
    "id" UUID NOT NULL,
    "rideId" UUID NOT NULL,
    "tokenHash" VARCHAR(64) NOT NULL,
    "createdByUserId" UUID NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "expiresAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ride_share_links_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "ride_share_links_tokenHash_key" ON "ride_share_links"("tokenHash");
CREATE INDEX "ride_share_links_rideId_expiresAt_idx" ON "ride_share_links"("rideId", "expiresAt");
ALTER TABLE "ride_share_links" ADD CONSTRAINT "ride_share_links_rideId_fkey" FOREIGN KEY ("rideId") REFERENCES "rides"("id") ON DELETE CASCADE ON UPDATE CASCADE;
