-- DEC-PROD-071 (DRAFT): admin parcel fees (service fee, return fee) snapshotted per parcel.
ALTER TYPE "CustomerFeeKind" ADD VALUE IF NOT EXISTS 'PARCEL_RETURN';

ALTER TABLE "ride_parcels" ADD COLUMN "serviceFeeVnd" INTEGER NOT NULL DEFAULT 0;
ALTER TABLE "ride_parcels" ADD COLUMN "returnFeeVnd" INTEGER NOT NULL DEFAULT 0;

INSERT INTO "platform_settings" ("id", "key", "value", "valueType", "updatedAt")
VALUES (gen_random_uuid(), 'PARCEL_SERVICE_FEE_VND', '0', 'number', CURRENT_TIMESTAMP)
ON CONFLICT ("key") DO NOTHING;
INSERT INTO "platform_settings" ("id", "key", "value", "valueType", "updatedAt")
VALUES (gen_random_uuid(), 'PARCEL_RETURN_FEE_VND', '10000', 'number', CURRENT_TIMESTAMP)
ON CONFLICT ("key") DO NOTHING;
