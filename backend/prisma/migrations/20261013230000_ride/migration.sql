-- CreateEnum
CREATE TYPE "RideStatus" AS ENUM ('NEGOTIATING', 'ASSIGNED', 'CANCELLED', 'EXPIRED');

-- CreateEnum
CREATE TYPE "RideOfferKind" AS ENUM ('ACCEPT', 'COUNTER');

-- CreateEnum
CREATE TYPE "RideOfferStatus" AS ENUM ('PENDING', 'SELECTED', 'LOST');

-- CreateTable
CREATE TABLE "rides" (
    "id" UUID NOT NULL,
    "customerId" UUID NOT NULL,
    "pickupLat" DOUBLE PRECISION NOT NULL,
    "pickupLng" DOUBLE PRECISION NOT NULL,
    "pickupLabel" VARCHAR(160) NOT NULL,
    "dropoffLat" DOUBLE PRECISION NOT NULL,
    "dropoffLng" DOUBLE PRECISION NOT NULL,
    "dropoffLabel" VARCHAR(160) NOT NULL,
    "offeredFareVnd" INTEGER NOT NULL,
    "referenceFareVnd" INTEGER NOT NULL,
    "agreedFareVnd" INTEGER,
    "status" "RideStatus" NOT NULL,
    "assignedDriverId" UUID,
    "selectedOfferId" UUID,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "idempotencyKey" VARCHAR(200) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "rides_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ride_offers" (
    "id" UUID NOT NULL,
    "rideId" UUID NOT NULL,
    "driverId" UUID NOT NULL,
    "amountVnd" INTEGER NOT NULL,
    "kind" "RideOfferKind" NOT NULL,
    "status" "RideOfferStatus" NOT NULL,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ride_offers_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ride_selections" (
    "id" UUID NOT NULL,
    "customerId" UUID NOT NULL,
    "idempotencyKey" VARCHAR(200) NOT NULL,
    "rideId" UUID NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ride_selections_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "rides_customerId_idempotencyKey_key" ON "rides"("customerId", "idempotencyKey");

-- CreateIndex
CREATE INDEX "rides_customerId_status_idx" ON "rides"("customerId", "status");

-- One NEGOTIATING row per customer. Terminal rows are not covered.
CREATE UNIQUE INDEX "rides_one_negotiating_per_customer" ON "rides"("customerId") WHERE "status" = 'NEGOTIATING';

-- CreateIndex
CREATE UNIQUE INDEX "rides_selectedOfferId_key" ON "rides"("selectedOfferId");

-- CreateIndex
CREATE UNIQUE INDEX "ride_offers_rideId_driverId_key" ON "ride_offers"("rideId", "driverId");

-- CreateIndex
CREATE UNIQUE INDEX "ride_selections_customerId_idempotencyKey_key" ON "ride_selections"("customerId", "idempotencyKey");

-- AddForeignKey
ALTER TABLE "rides" ADD CONSTRAINT "rides_customerId_fkey" FOREIGN KEY ("customerId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "rides" ADD CONSTRAINT "rides_assignedDriverId_fkey" FOREIGN KEY ("assignedDriverId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ride_offers" ADD CONSTRAINT "ride_offers_rideId_fkey" FOREIGN KEY ("rideId") REFERENCES "rides"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ride_offers" ADD CONSTRAINT "ride_offers_driverId_fkey" FOREIGN KEY ("driverId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "rides" ADD CONSTRAINT "rides_selectedOfferId_fkey" FOREIGN KEY ("selectedOfferId") REFERENCES "ride_offers"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ride_selections" ADD CONSTRAINT "ride_selections_customerId_fkey" FOREIGN KEY ("customerId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ride_selections" ADD CONSTRAINT "ride_selections_rideId_fkey" FOREIGN KEY ("rideId") REFERENCES "rides"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
