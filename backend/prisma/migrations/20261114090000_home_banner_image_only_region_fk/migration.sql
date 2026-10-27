-- Home banners are image-only: the art carries any wording, so the text columns go.
ALTER TABLE "home_banners" DROP COLUMN "title",
DROP COLUMN "subtitle";

-- Region targeting points at the Admin-managed service regions (/zones).
-- A code that no longer matches a region falls back to "all regions".
UPDATE "home_banners" SET "regionCode" = NULL
WHERE "regionCode" IS NOT NULL
  AND "regionCode" NOT IN (SELECT "code" FROM "service_regions");

-- CreateIndex
CREATE INDEX "home_banners_regionCode_idx" ON "home_banners"("regionCode");

-- AddForeignKey
ALTER TABLE "home_banners" ADD CONSTRAINT "home_banners_regionCode_fkey" FOREIGN KEY ("regionCode") REFERENCES "service_regions"("code") ON DELETE RESTRICT ON UPDATE CASCADE;
