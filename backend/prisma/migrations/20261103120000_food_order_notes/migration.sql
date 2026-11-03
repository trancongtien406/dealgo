-- Additive only: nullable note columns and a defaulted utensils flag; no backfill.

-- AlterTable
ALTER TABLE "food_orders" ADD COLUMN "note" VARCHAR(300);
ALTER TABLE "food_orders" ADD COLUMN "utensils" BOOLEAN NOT NULL DEFAULT true;

-- AlterTable
ALTER TABLE "food_order_lines" ADD COLUMN "note" VARCHAR(200);
