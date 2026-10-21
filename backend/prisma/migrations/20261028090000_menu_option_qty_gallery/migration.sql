-- DEC-PROD-042: per-option max quantity + multi-image gallery + sold count cache.
ALTER TABLE "food_options" ADD COLUMN IF NOT EXISTS "maxQuantity" SMALLINT NOT NULL DEFAULT 1;
ALTER TABLE "food_items" ADD COLUMN IF NOT EXISTS "imageUrls" JSONB NOT NULL DEFAULT '[]'::jsonb;
ALTER TABLE "food_items" ADD COLUMN IF NOT EXISTS "soldCount" INTEGER NOT NULL DEFAULT 0;

-- Backfill cover into imageUrls when present.
UPDATE "food_items"
SET "imageUrls" = jsonb_build_array("imageUrl")
WHERE "imageUrl" IS NOT NULL
  AND "imageUrl" <> ''
  AND ("imageUrls" = '[]'::jsonb OR "imageUrls" IS NULL);
