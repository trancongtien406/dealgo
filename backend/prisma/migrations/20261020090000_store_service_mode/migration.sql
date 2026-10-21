-- DEC-PROD-026: M024 busy / pause mode is stored on the store and enforced when an order is placed.
CREATE TYPE "StoreServiceMode" AS ENUM ('OPEN', 'BUSY', 'PAUSED');

ALTER TABLE "food_stores" ADD COLUMN "serviceMode" "StoreServiceMode" NOT NULL DEFAULT 'OPEN',
ADD COLUMN "serviceModeUntil" TIMESTAMP(3);
