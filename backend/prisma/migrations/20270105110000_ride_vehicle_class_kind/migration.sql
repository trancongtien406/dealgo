-- RIDE-004/005: explicit BIKE | CAR kind per vehicle class (car KYC docs, licence, commission).
CREATE TYPE "VehicleKind" AS ENUM ('BIKE', 'CAR');

ALTER TABLE "ride_vehicle_classes" ADD COLUMN "kind" "VehicleKind" NOT NULL DEFAULT 'BIKE';

-- Backward compatibility: existing CAR_4 / CAR_7 (and any non-motorbike code) are cars.
UPDATE "ride_vehicle_classes"
SET "kind" = 'CAR'
WHERE "code" !~* '^(MOTOR|BIKE)';
