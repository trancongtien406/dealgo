-- Dish list price shown struck through next to the selling price.
ALTER TABLE "food_items" ADD COLUMN "originalPriceVnd" INTEGER;

-- Store minimum food subtotal; 0 = no minimum.
ALTER TABLE "food_stores" ADD COLUMN "minOrderVnd" INTEGER NOT NULL DEFAULT 0;
