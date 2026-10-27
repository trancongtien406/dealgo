-- Bring migrations in line with schema.prisma (found by `prisma migrate diff` while baselining the dev DB):
-- RideVehicleClass.updatedAt is @updatedAt (no DB default) and rides has @@index([status, vehicleClassCode]).

-- AlterTable
ALTER TABLE "ride_vehicle_classes" ALTER COLUMN "updatedAt" DROP DEFAULT;

-- CreateIndex
CREATE INDEX "rides_status_vehicleClassCode_idx" ON "rides"("status", "vehicleClassCode");
