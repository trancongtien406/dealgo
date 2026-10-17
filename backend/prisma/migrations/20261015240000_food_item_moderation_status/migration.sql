-- Catalog moderation status for ops approve/reject (distinct from available).
CREATE TYPE "FoodItemModerationStatus" AS ENUM ('PENDING', 'APPROVED', 'REJECTED');

ALTER TABLE "food_items"
  ADD COLUMN "moderationStatus" "FoodItemModerationStatus" NOT NULL DEFAULT 'APPROVED';

UPDATE "food_items"
SET "moderationStatus" = CASE
  WHEN "available" THEN 'APPROVED'::"FoodItemModerationStatus"
  ELSE 'PENDING'::"FoodItemModerationStatus"
END;

CREATE INDEX "food_items_moderationStatus_idx" ON "food_items"("moderationStatus");
