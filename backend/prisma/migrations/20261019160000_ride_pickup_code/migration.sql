-- DEC-PROD-017: server-issued pickup codes (replaces the client-derived / hardcoded code).
CREATE TABLE "ride_pickup_codes" (
    "rideId" UUID NOT NULL,
    "code" VARCHAR(8) NOT NULL,
    "failedAttempts" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "verifiedAt" TIMESTAMP(3),

    CONSTRAINT "ride_pickup_codes_pkey" PRIMARY KEY ("rideId")
);

ALTER TABLE "ride_pickup_codes" ADD CONSTRAINT "ride_pickup_codes_rideId_fkey" FOREIGN KEY ("rideId") REFERENCES "rides"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- Wrong codes a driver may submit before the ride's code locks (ops then cancels/reassigns).
INSERT INTO "platform_settings" ("id", "key", "value", "valueType", "updatedAt")
VALUES (gen_random_uuid(), 'RIDE_PICKUP_CODE_MAX_ATTEMPTS', '5', 'number', CURRENT_TIMESTAMP)
ON CONFLICT ("key") DO NOTHING;
