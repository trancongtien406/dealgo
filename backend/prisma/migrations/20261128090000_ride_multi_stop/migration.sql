-- Multi-stop rides (feature-flagged, default OFF). Backward compatible: pickup/dropoff columns stay
-- the first/last point; intermediate stops live in ride_stops.
ALTER TABLE "rides"
  ADD COLUMN "routeVersion" INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN "stopCount" INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN "stopFeeVnd" INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN "stopWaitFreeMinutes" INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN "stopWaitFeeVndPerMinute" INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN "waitFeeVnd" INTEGER NOT NULL DEFAULT 0;

CREATE TABLE "ride_stops" (
  "id" UUID NOT NULL,
  "rideId" UUID NOT NULL,
  "seq" INTEGER NOT NULL,
  "lat" DOUBLE PRECISION NOT NULL,
  "lng" DOUBLE PRECISION NOT NULL,
  "label" VARCHAR(160) NOT NULL,
  "arrivedAt" TIMESTAMP(3),
  "departedAt" TIMESTAMP(3),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "ride_stops_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "ride_stops_rideId_seq_key" ON "ride_stops"("rideId", "seq");
ALTER TABLE "ride_stops" ADD CONSTRAINT "ride_stops_rideId_fkey"
  FOREIGN KEY ("rideId") REFERENCES "rides"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- DRAFT defaults; admins change them on the Settings page. Flags start OFF.
INSERT INTO "platform_settings" ("id", "key", "value", "valueType", "updatedAt") VALUES
  (gen_random_uuid(), 'RIDE_MULTI_STOP_BIKE_ENABLED', 'false', 'json', CURRENT_TIMESTAMP),
  (gen_random_uuid(), 'RIDE_MULTI_STOP_CAR_ENABLED', 'false', 'json', CURRENT_TIMESTAMP),
  (gen_random_uuid(), 'RIDE_MAX_STOPS_BIKE', '1', 'number', CURRENT_TIMESTAMP),
  (gen_random_uuid(), 'RIDE_MAX_STOPS_CAR', '2', 'number', CURRENT_TIMESTAMP),
  (gen_random_uuid(), 'RIDE_STOP_FEE_BIKE_VND', '5000', 'number', CURRENT_TIMESTAMP),
  (gen_random_uuid(), 'RIDE_STOP_FEE_CAR_VND', '10000', 'number', CURRENT_TIMESTAMP),
  (gen_random_uuid(), 'RIDE_STOP_FREE_WAIT_MINUTES', '5', 'number', CURRENT_TIMESTAMP),
  (gen_random_uuid(), 'RIDE_STOP_WAIT_FEE_VND_PER_MINUTE', '1000', 'number', CURRENT_TIMESTAMP)
ON CONFLICT ("key") DO NOTHING;
