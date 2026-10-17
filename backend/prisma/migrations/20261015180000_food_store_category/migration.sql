-- AlterTable
ALTER TABLE "food_stores" ADD COLUMN "category" VARCHAR(64);

-- CreateIndex
CREATE INDEX "food_stores_category_idx" ON "food_stores"("category");
