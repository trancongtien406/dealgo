-- DEC-PROD-027: M023 opening hours, special closed days and last-order cut-off (Vietnam local time).
-- Existing stores keep hoursConfigured = false and stay open around the clock.
-- AlterTable
ALTER TABLE "food_stores" ADD COLUMN     "hoursConfigured" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "lastOrderMinutes" INTEGER NOT NULL DEFAULT 0;

-- CreateTable
CREATE TABLE "food_store_hours" (
    "storeId" UUID NOT NULL,
    "weekday" SMALLINT NOT NULL,
    "opensMinute" SMALLINT NOT NULL,
    "closesMinute" SMALLINT NOT NULL,

    CONSTRAINT "food_store_hours_pkey" PRIMARY KEY ("storeId","weekday")
);

-- CreateTable
CREATE TABLE "food_store_closures" (
    "storeId" UUID NOT NULL,
    "date" DATE NOT NULL,
    "note" VARCHAR(120),

    CONSTRAINT "food_store_closures_pkey" PRIMARY KEY ("storeId","date")
);

-- AddForeignKey
ALTER TABLE "food_store_hours" ADD CONSTRAINT "food_store_hours_storeId_fkey" FOREIGN KEY ("storeId") REFERENCES "food_stores"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "food_store_closures" ADD CONSTRAINT "food_store_closures_storeId_fkey" FOREIGN KEY ("storeId") REFERENCES "food_stores"("id") ON DELETE CASCADE ON UPDATE CASCADE;


ALTER TABLE "food_store_hours" ADD CONSTRAINT "food_store_hours_range" CHECK ("weekday" BETWEEN 1 AND 7 AND "opensMinute" >= 0 AND "closesMinute" <= 1440 AND "closesMinute" > "opensMinute");
