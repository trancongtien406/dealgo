-- DEC-PROD-023: per-service duty toggles (ride requests / food deliveries) on driver presence.
ALTER TABLE "driver_presence" ADD COLUMN "rideEnabled" BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE "driver_presence" ADD COLUMN "foodEnabled" BOOLEAN NOT NULL DEFAULT true;
