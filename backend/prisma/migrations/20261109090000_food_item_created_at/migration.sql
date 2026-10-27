-- Submission time for menu items: the Ops catalog review list filters and shows it.
-- Rows that existed before this column get the migration time.
ALTER TABLE "food_items" ADD COLUMN "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;
