-- DEC-PROD-071 (DRAFT): parcel (goods) delivery on top of the ride stack.
CREATE TYPE "ParcelSizeClass" AS ENUM ('S', 'M', 'L', 'XL');
CREATE TYPE "ParcelPayer" AS ENUM ('SENDER', 'RECIPIENT');
CREATE TYPE "ParcelOutcome" AS ENUM ('PENDING', 'DELIVERED', 'RETURNING', 'RETURNED');

ALTER TABLE "ride_vehicle_classes" ADD COLUMN "parcelEnabled" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "driver_presence" ADD COLUMN "parcelEnabled" BOOLEAN NOT NULL DEFAULT false;

CREATE TABLE "ride_parcels" (
    "rideId" UUID NOT NULL,
    "senderName" VARCHAR(80) NOT NULL,
    "senderPhone" VARCHAR(20) NOT NULL,
    "recipientName" VARCHAR(80) NOT NULL,
    "recipientPhone" VARCHAR(20) NOT NULL,
    "sizeClass" "ParcelSizeClass" NOT NULL,
    "weightKg" DOUBLE PRECISION,
    "note" VARCHAR(300),
    "payer" "ParcelPayer" NOT NULL DEFAULT 'SENDER',
    "surchargeVnd" INTEGER NOT NULL DEFAULT 0,
    "itemPhoto" JSONB,
    "recipientCode" VARCHAR(8),
    "recipientCodeFails" INTEGER NOT NULL DEFAULT 0,
    "pickupPhoto" JSONB,
    "pickedUpAt" TIMESTAMP(3),
    "deliveryPhoto" JSONB,
    "deliveredAt" TIMESTAMP(3),
    "outcome" "ParcelOutcome" NOT NULL DEFAULT 'PENDING',
    "failReason" VARCHAR(40),
    "failNote" VARCHAR(300),
    "failedAt" TIMESTAMP(3),
    "returnPhoto" JSONB,
    "returnedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "ride_parcels_pkey" PRIMARY KEY ("rideId")
);
CREATE INDEX "ride_parcels_outcome_createdAt_idx" ON "ride_parcels"("outcome", "createdAt");
ALTER TABLE "ride_parcels" ADD CONSTRAINT "ride_parcels_rideId_fkey" FOREIGN KEY ("rideId") REFERENCES "rides"("id") ON DELETE CASCADE ON UPDATE CASCADE;
