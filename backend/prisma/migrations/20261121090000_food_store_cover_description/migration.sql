-- Merchant cover photo for the store page hero; null = first dish photo.
ALTER TABLE "food_stores" ADD COLUMN "coverUrl" VARCHAR(400);

-- Short "about the store" text the merchant writes; null = none.
ALTER TABLE "food_stores" ADD COLUMN "description" VARCHAR(500);
