CREATE TABLE "ride_vehicle_classes" (
    "code" VARCHAR(32) NOT NULL,
    "name" VARCHAR(80) NOT NULL,
    "seats" INTEGER NOT NULL,
    "enabled" BOOLEAN NOT NULL DEFAULT true,
    "baseFareVnd" INTEGER NOT NULL,
    "perKmVnd" INTEGER NOT NULL,
    "perMinuteVnd" INTEGER NOT NULL,
    "minFareVnd" INTEGER NOT NULL,
    "maxFareVnd" INTEGER NOT NULL,
    "assumedSpeedKmh" INTEGER NOT NULL,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "updatedByUserId" UUID,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ride_vehicle_classes_pkey" PRIMARY KEY ("code")
);

ALTER TABLE "rides" ADD COLUMN "vehicleClassCode" VARCHAR(32) NOT NULL DEFAULT 'MOTORBIKE';
