-- DEC-PROD-029: closesMinute < opensMinute is an overnight shift ending the next morning.
-- 00:00 as a closing time is stored as 1440, so closesMinute stays in 1..1440.
ALTER TABLE "food_store_hours" DROP CONSTRAINT "food_store_hours_range";
ALTER TABLE "food_store_hours" ADD CONSTRAINT "food_store_hours_range" CHECK (
  "weekday" BETWEEN 1 AND 7
  AND "opensMinute" BETWEEN 0 AND 1439
  AND "closesMinute" BETWEEN 1 AND 1440
  AND "closesMinute" <> "opensMinute"
);
