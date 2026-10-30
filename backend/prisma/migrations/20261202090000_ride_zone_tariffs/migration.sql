-- Per-zone tariff overrides (empty by default: every zone uses the global class tariff)
-- and the pricing snapshot locked onto each ride at booking (owner t50u).
CREATE TABLE IF NOT EXISTS "ride_zone_tariffs" (
    "id" UUID NOT NULL,
    "regionCode" VARCHAR(8) NOT NULL,
    "vehicleClassCode" VARCHAR(32) NOT NULL,
    "perKmVnd" INTEGER NOT NULL,
    "minFareVnd" INTEGER NOT NULL,
    "version" INTEGER NOT NULL DEFAULT 1,
    "updatedByUserId" UUID,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "ride_zone_tariffs_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX IF NOT EXISTS "ride_zone_tariffs_regionCode_vehicleClassCode_key"
    ON "ride_zone_tariffs"("regionCode", "vehicleClassCode");

CREATE TABLE IF NOT EXISTS "ride_pricing_snapshots" (
    "rideId" UUID NOT NULL,
    "regionCode" VARCHAR(8),
    "tariffSource" VARCHAR(8) NOT NULL,
    "zoneTariffId" UUID,
    "tariffVersion" INTEGER NOT NULL DEFAULT 0,
    "perKmVnd" INTEGER NOT NULL,
    "minFareVnd" INTEGER NOT NULL,
    "bidFloorPercent" INTEGER NOT NULL,
    "bidCeilingPercent" INTEGER NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "ride_pricing_snapshots_pkey" PRIMARY KEY ("rideId")
);

-- Ops audit trail for zone tariff edits.
ALTER TYPE "OpsAuditAction" ADD VALUE IF NOT EXISTS 'RIDE_ZONE_TARIFF_UPSERT';
ALTER TYPE "OpsAuditAction" ADD VALUE IF NOT EXISTS 'RIDE_ZONE_TARIFF_DELETE';
ALTER TYPE "OpsAuditEntityType" ADD VALUE IF NOT EXISTS 'RIDE_ZONE_TARIFF';
