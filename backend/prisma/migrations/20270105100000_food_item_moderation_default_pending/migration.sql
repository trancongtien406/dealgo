-- FOOD-001: new menu items start PENDING and cannot be sold until ops approves them.
ALTER TABLE "food_items" ALTER COLUMN "moderationStatus" SET DEFAULT 'PENDING';
